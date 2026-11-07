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

describe('herdr_review.send with a new agent', function()
    local herdr_review
    local messages
    local select_calls
    local fake
    local original_cwd
    local repo
    local buf

    local wait_for = function(condition)
        assert.is_true(vim.wait(2000, condition, 10))
    end

    local choose_new_agent = function()
        herdr_review.send()
        wait_for(function()
            return #select_calls > 0
        end)
        select_calls[1].on_choice(select_calls[1].items[#select_calls[1].items])
    end

    local mark_count = function()
        return #vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {})
    end

    before_each(function()
        herdr_review = fresh_plugin()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
        messages = {}
        select_calls = {}
        vim.notify = function(message, level)
            table.insert(messages, { message = message, level = level })
        end
        vim.ui.select = function(items, opts, on_choice)
            table.insert(select_calls, { items = items, opts = opts, on_choice = on_choice })
        end
        fake = fake_herdr.install()
        fake.reply('pane current', vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } }))
        fake.reply(
            'agent list',
            vim.json.encode({
                result = {
                    agents = {
                        {
                            pane_id = 'w1:p1',
                            workspace_id = 'w1',
                            agent_status = 'idle',
                            terminal_title_stripped = 'Fix the parser',
                        },
                    },
                },
            })
        )
        fake.reply(
            'tab create',
            vim.json.encode({ result = { root_pane = { pane_id = 'w1:p7' }, tab = { tab_id = 'w1:t2' } } })
        )
        fake.reply('agent start', '{}')
        fake.reply('agent prompt', '{}')
        fake.reply('agent focus', '{}')
        original_cwd = vim.fn.getcwd()
        repo = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(repo, 'p')
        vim.system({ 'git', 'init', '-b', 'main' }, { cwd = repo }):wait()
        vim.cmd.cd(repo)
        vim.fn.writefile({ 'one', 'two', 'three' }, repo .. '/main.lua')
        vim.cmd.edit(repo .. '/main.lua')
        buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys('fix this', 'tx', false)
        vim.cmd('quit')
    end)

    after_each(function()
        fake.uninstall()
        vim.cmd.cd(original_cwd)
        vim.notify = original_notify
        vim.ui.select = original_select
    end)

    it('offers a new agent last in the list, after the existing agents', function()
        herdr_review.send()
        wait_for(function()
            return #select_calls > 0
        end)

        local call = select_calls[1]
        assert.are.equal('Send the review to', call.opts.prompt)
        assert.are.equal('Fix the parser (idle)', call.opts.format_item(call.items[1]))
        assert.are.equal('New agent', call.opts.format_item(call.items[2]))
    end)

    it('creates a tab, starts the agent, prompts it then focuses it', function()
        choose_new_agent()
        wait_for(function()
            return #fake.calls() >= 6
        end)

        local calls = fake.calls()
        assert.are.same({ 'tab', 'create', '--workspace', 'w1', '--cwd', repo, '--focus' }, calls[3])
        assert.are.same({ 'agent', 'start' }, vim.list_slice(calls[4], 1, 2))
        assert.is_truthy(calls[4][3]:match('^review%-%d%d%d%d%d%d$'))
        assert.are.same({ '--kind', 'claude', '--pane', 'w1:p7' }, vim.list_slice(calls[4], 4, 7))
        assert.are.same({ 'agent', 'prompt', 'w1:p7' }, vim.list_slice(calls[5], 1, 3))
        assert.is_truthy(calls[5][4]:find('fix this', 1, true))
        assert.are.same({ 'agent', 'focus', 'w1:p7' }, calls[6])
    end)

    it('starts the agent named in setup()', function()
        herdr_review.setup({ agent = 'copilot' })
        choose_new_agent()
        wait_for(function()
            return #fake.calls() >= 6
        end)

        assert.are.same({ '--kind', 'copilot' }, vim.list_slice(fake.calls()[4], 4, 5))
    end)

    it('lets nvim run while the agent starts', function()
        choose_new_agent()
        local ticked = false
        vim.schedule(function()
            ticked = true
        end)

        assert.is_true(vim.wait(2000, function()
            return ticked
        end, 1))
        assert.is_true(#fake.calls() < 6)
        wait_for(function()
            return #fake.calls() >= 6
        end)
    end)

    it('shows the error and keeps the notes when tab create fails', function()
        fake.reply('tab create', vim.json.encode({ error = { code = 'boom', message = 'no tab' } }), 1)
        choose_new_agent()
        wait_for(function()
            return #messages > 0
        end)

        assert.is_truthy(messages[1].message:find('no tab', 1, true))
        assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        assert.are.equal(3, #fake.calls())
        assert.is_true(mark_count() > 0)
    end)

    it('sends nothing and keeps the notes when agent start fails', function()
        fake.reply('agent start', vim.json.encode({ error = { code = 'timeout', message = 'not ready' } }), 1)
        choose_new_agent()
        wait_for(function()
            return #messages > 0
        end)

        assert.is_truthy(messages[1].message:find('not ready', 1, true))
        assert.are.equal(4, #fake.calls())
        assert.is_true(mark_count() > 0)
    end)
end)
