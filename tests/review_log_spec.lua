local fake_herdr = require('tests.support.fake_herdr')
local original_notify = vim.notify
local original_select = vim.ui.select

local fresh_plugin = function()
    for name in pairs(package.loaded) do
        if name:find('^herdr_review') then
            package.loaded[name] = nil
        end
    end
    return require('herdr_review')
end

local wait_for = function(condition)
    assert.is_true(vim.wait(2000, condition, 10))
end

local list_with_one_agent = vim.json.encode({
    result = {
        agents = {
            {
                pane_id = 'w1:p1',
                tab_id = 'w1:t1',
                workspace_id = 'w1',
                agent_status = 'idle',
                terminal_title_stripped = 'Fix the parser',
            },
        },
    },
})

describe('review log', function()
    local herdr_review
    local fake
    local select_calls
    local original_cwd
    local original_state
    local repo
    local log_dir

    local comment = function(text)
        vim.cmd.edit(repo .. '/main.lua')
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys(text, 'tx', false)
        vim.cmd('quit')
    end

    local send_and_choose = function()
        select_calls = {}
        herdr_review.send()
        wait_for(function()
            return #select_calls > 0
        end)
        select_calls[1].on_choice(select_calls[1].items[1])
    end

    local logged_files = function()
        return vim.fn.glob(log_dir .. '/*', false, true)
    end

    before_each(function()
        herdr_review = fresh_plugin()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
        select_calls = {}
        vim.notify = function() end
        vim.ui.select = function(items, opts, on_choice)
            table.insert(select_calls, { items = items, opts = opts, on_choice = on_choice })
        end
        fake = fake_herdr.install()
        fake.reply('pane current', vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } }))
        fake.reply('agent list', list_with_one_agent)
        fake.reply('agent prompt', '{}')
        fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
        fake.reply('agent focus', '{}')
        original_cwd = vim.fn.getcwd()
        original_state = vim.env.XDG_STATE_HOME
        vim.env.XDG_STATE_HOME = vim.fn.resolve(vim.fn.tempname())
        repo = vim.fn.resolve(vim.fn.tempname()) .. '/my-repo'
        vim.fn.mkdir(repo, 'p')
        vim.system({ 'git', 'init', '-b', 'main' }, { cwd = repo }):wait()
        vim.cmd.cd(repo)
        vim.fn.writefile({ 'one', 'two', 'three' }, repo .. '/main.lua')
        log_dir = vim.fn.stdpath('state') .. '/herdr-review/my-repo'
    end)

    after_each(function()
        fake.uninstall()
        vim.cmd.cd(original_cwd)
        vim.env.XDG_STATE_HOME = original_state
        vim.notify = original_notify
        vim.ui.select = original_select
    end)

    it('writes the exact prompt to a timestamped file under the repo folder', function()
        comment('fix this')
        send_and_choose()
        wait_for(function()
            return #fake.calls() >= 5
        end)

        local files = logged_files()
        assert.are.equal(1, #files)
        assert.is_truthy(vim.fs.basename(files[1]):match('^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%d%d%.md$'))
        assert.are.equal(fake.calls()[4][4], table.concat(vim.fn.readfile(files[1], 'b'), '\n'))
    end)

    it('keeps the file and its folder readable by the user alone', function()
        comment('fix this')
        send_and_choose()
        wait_for(function()
            return #fake.calls() >= 5
        end)

        local permissions = function(path)
            return string.format('%o', bit.band(vim.uv.fs_stat(path).mode, tonumber('777', 8)))
        end
        assert.are.equal('700', permissions(log_dir))
        assert.are.equal('600', permissions(logged_files()[1]))
    end)

    it('keeps both files when two sends land in the same second', function()
        comment('first')
        send_and_choose()
        wait_for(function()
            return #fake.calls() >= 5
        end)
        comment('second')
        send_and_choose()
        wait_for(function()
            return #fake.calls() >= 10
        end)

        assert.are.equal(2, #logged_files())
    end)

    it('still focuses the agent and reports when the log cannot be written', function()
        local blocker = vim.fn.tempname()
        vim.fn.writefile({}, blocker)
        vim.env.XDG_STATE_HOME = blocker
        local messages = {}
        vim.notify = function(message, level)
            table.insert(messages, { message = message, level = level })
        end
        comment('fix this')
        send_and_choose()
        wait_for(function()
            return #messages > 0
        end)

        wait_for(function()
            return #fake.calls() >= 5
        end)
        assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        assert.are.same({ 'agent', 'focus', 'w1:p1' }, fake.calls()[5])
        herdr_review.send()
        assert.are.equal('No note to send', messages[#messages].message)
    end)

    it('writes nothing when the agent is blocked', function()
        fake.reply('agent prompt', vim.json.encode({ error = { code = 'agent_blocked', message = 'waiting' } }), 1)
        comment('fix this')
        send_and_choose()
        wait_for(function()
            return #fake.calls() >= 4
        end)
        vim.wait(100)

        assert.are.same({}, logged_files())
    end)

    it('writes nothing when the list is cancelled', function()
        comment('fix this')
        select_calls = {}
        herdr_review.send()
        wait_for(function()
            return #select_calls > 0
        end)
        select_calls[1].on_choice(nil)
        vim.wait(100)

        assert.are.same({}, logged_files())
    end)
end)
