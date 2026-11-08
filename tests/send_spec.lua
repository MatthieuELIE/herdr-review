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

describe('herdr_review.send', function()
    local herdr_review
    local messages
    local select_calls

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
    end)

    after_each(function()
        vim.notify = original_notify
        vim.ui.select = original_select
    end)

    describe('with a note', function()
        local fake
        local original_cwd
        local repo

        local agent_list = vim.json.encode({
            id = 'cli:agent:list',
            result = {
                agents = {
                    {
                        pane_id = 'w1:p1',
                        tab_id = 'w1:t1',
                        workspace_id = 'w1',
                        agent_status = 'idle',
                        terminal_title_stripped = 'Fix the parser',
                    },
                    {
                        pane_id = 'w2:p1',
                        tab_id = 'w2:t1',
                        workspace_id = 'w2',
                        agent_status = 'working',
                        terminal_title_stripped = 'Other project',
                    },
                    {
                        pane_id = 'w1:p2',
                        tab_id = 'w1:t2',
                        workspace_id = 'w1',
                        agent_status = 'working',
                        terminal_title_stripped = 'Write the docs',
                    },
                },
            },
        })

        local tab_list = vim.json.encode({
            id = 'cli:tab:list',
            result = {
                tabs = {
                    { tab_id = 'w1:t1', label = 'parser' },
                    { tab_id = 'w1:t2', label = 'docs' },
                    { tab_id = 'w1:t3', label = 'nvim' },
                    { tab_id = 'w2:t1', label = 'other' },
                },
            },
        })

        local git = function(...)
            vim.system({ 'git', ... }, { cwd = repo }):wait()
        end

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply('agent list', agent_list)
            fake.reply('agent prompt', '{}')
            fake.reply('tab list', tab_list)
            fake.reply('agent focus', '{}')
            original_cwd = vim.fn.getcwd()
            repo = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(repo, 'p')
            git('init', '-b', 'main')
            vim.cmd.cd(repo)
            vim.fn.writefile({ 'one', 'two', 'three' }, repo .. '/main.lua')
            vim.cmd.edit(repo .. '/main.lua')
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('fix this', 'tx', false)
            vim.cmd('quit')
        end)

        after_each(function()
            fake.uninstall()
            vim.cmd.cd(original_cwd)
        end)

        it('lists the agents of the nvim workspace by their tab label and status', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)

            local call = select_calls[1]
            assert.are.equal(3, #call.items)
            assert.are.equal('parser (idle)', call.opts.format_item(call.items[1]))
            assert.are.equal('docs (working)', call.opts.format_item(call.items[2]))
        end)

        it('gives two agents in tabs of the same label the same entry', function()
            fake.reply(
                'tab list',
                vim.json.encode({
                    result = {
                        tabs = { { tab_id = 'w1:t1', label = 'claude' }, { tab_id = 'w1:t2', label = 'claude' } },
                    },
                })
            )
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)

            local call = select_calls[1]
            assert.are.equal('claude (idle)', call.opts.format_item(call.items[1]))
            assert.are.equal('claude (working)', call.opts.format_item(call.items[2]))
        end)

        it('sends the review to the chosen agent with herdr agent prompt', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[2])
            wait_for(function()
                return #fake.calls() >= 5
            end)

            local prompt = fake.calls()[4]
            assert.are.same({ 'agent', 'prompt', 'w1:p2' }, vim.list_slice(prompt, 1, 3))
            assert.is_truthy(prompt[4]:find('fix this', 1, true))
        end)
    end)

    describe('after a successful send', function()
        local fake
        local original_cwd
        local buf

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply(
                'agent list',
                vim.json.encode({
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
            )
            fake.reply('agent prompt', '{}')
            fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
            fake.reply('agent focus', '{}')
            original_cwd = vim.fn.getcwd()
            local path = vim.fn.tempname()
            vim.fn.writefile({ 'one', 'two', 'three' }, path)
            vim.cmd.edit(path)
            buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('fix this', 'tx', false)
            vim.cmd('quit')
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[1])
            wait_for(function()
                return #fake.calls() >= 5
            end)
        end)

        after_each(function()
            fake.uninstall()
            vim.cmd.cd(original_cwd)
        end)

        it('focuses the pane of the agent', function()
            assert.are.same({ 'agent', 'focus', 'w1:p1' }, fake.calls()[5])
        end)

        it('removes every note from every buffer', function()
            assert.are.same({}, vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {}))

            herdr_review.send()
            assert.are.equal('No note to send', messages[#messages].message)
        end)
    end)

    describe('a note added while the list is open', function()
        local fake

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply(
                'agent list',
                vim.json.encode({
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
            )
            fake.reply('agent prompt', '{}')
            fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
            fake.reply('agent focus', '{}')
        end)

        after_each(function()
            fake.uninstall()
        end)

        it('is kept, shown and sent in the next review', function()
            local path = vim.fn.tempname()
            vim.fn.writefile({ 'one', 'two', 'three' }, path)
            vim.cmd.edit(path)
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('first', 'tx', false)
            vim.cmd('quit')
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)

            vim.api.nvim_win_set_cursor(0, { 3, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('second', 'tx', false)
            vim.cmd('quit')
            select_calls[1].on_choice(select_calls[1].items[1])
            wait_for(function()
                return #fake.calls() >= 5
            end)

            assert.are.equal(2, #vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {}))
            select_calls = {}
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[1])
            wait_for(function()
                return #fake.calls() >= 10
            end)
            local review = fake.calls()[9][4]
            assert.is_truthy(review:find('second', 1, true))
            assert.is_nil(review:find('first', 1, true))
        end)
    end)

    describe('when the send does not complete', function()
        local fake
        local buf

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        local blocked = vim.json.encode({
            error = { code = 'agent_blocked', message = 'agent is waiting on a question' },
        })

        local list_with_one_agent = vim.json.encode({
            result = {
                agents = {
                    {
                        pane_id = 'w1:p1',
                        tab_id = 'w1:t1',
                        workspace_id = 'w1',
                        agent_status = 'blocked',
                        terminal_title_stripped = 'Fix the parser',
                    },
                },
            },
        })

        local assert_notes_kept = function()
            assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {}) > 0)
            select_calls = {}
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply('agent list', list_with_one_agent)
            fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
            fake.reply('agent focus', '{}')
            local path = vim.fn.tempname()
            vim.fn.writefile({ 'one', 'two', 'three' }, path)
            vim.cmd.edit(path)
            buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('fix this', 'tx', false)
            vim.cmd('quit')
        end)

        after_each(function()
            fake.uninstall()
        end)

        it('shows the error, does not focus and keeps the notes when the agent is blocked', function()
            fake.reply('agent prompt', blocked, 1)
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[1])
            wait_for(function()
                return #messages > 0
            end)

            assert.is_truthy(messages[1].message:find('agent_blocked', 1, true))
            assert.are.equal(vim.log.levels.ERROR, messages[1].level)
            assert.are.equal(4, #fake.calls())
            assert_notes_kept()
        end)

        it('shows the error and keeps the notes when nvim runs outside Herdr', function()
            fake.reply(
                'pane current',
                vim.json.encode({ error = { code = 'not_in_herdr', message = 'not inside a herdr pane' } }),
                1
            )
            herdr_review.send()
            wait_for(function()
                return #messages > 0
            end)

            assert.are.equal('not_in_herdr: not inside a herdr pane', messages[1].message)
            assert.are.equal(0, #select_calls)
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            assert_notes_kept()
        end)

        it('shows the error and keeps the notes when herdr is not installed', function()
            fake.uninstall()
            local original_path = vim.env.PATH
            vim.env.PATH = vim.fn.resolve(vim.fn.tempname())
            herdr_review.send()
            wait_for(function()
                return #messages > 0
            end)
            vim.env.PATH = original_path

            assert.is_truthy(messages[1].message:find('^herdr could not be run: '))
            assert.are.equal(0, #select_calls)
        end)

        local error_messages = function()
            local errors = vim.tbl_filter(function(message)
                return message.level == vim.log.levels.ERROR
            end, messages)

            return vim.tbl_map(function(message)
                return message.message
            end, errors)
        end

        it('shows the plain stderr when herdr fails without JSON', function()
            fake.reply('pane current', 'boom', 1)
            herdr_review.send()
            wait_for(function()
                return #error_messages() > 0
            end)

            assert.are.same({ 'herdr failed: boom' }, error_messages())
            assert.are.equal(0, #select_calls)
        end)

        it('shows the plain stderr when herdr fails with JSON that holds no error', function()
            fake.reply('pane current', '{"id":"cli:pane:current"}', 1)
            herdr_review.send()
            wait_for(function()
                return #error_messages() > 0
            end)

            assert.are.same({ 'herdr failed: {"id":"cli:pane:current"}' }, error_messages())
            assert.are.equal(0, #select_calls)
        end)

        it('does nothing and keeps the notes when the list is cancelled', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(nil)

            assert.are.equal(3, #fake.calls())
            assert.are.same({}, messages)
            assert_notes_kept()
        end)
    end)

    describe('review content', function()
        local fake
        local original_cwd
        local repo

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        local comment_lines = function(path, first, last, text)
            vim.cmd.edit(path)
            vim.api.nvim_win_set_cursor(0, { first, 0 })
            vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)
            local select_keys = ''
            if last > first then
                select_keys = 'V' .. (last - first) .. 'j'
            end
            vim.api.nvim_feedkeys(select_keys .. vim.keycode('<Leader>') .. 'ac' .. text, 'tx', false)
            vim.cmd('quit')
        end

        local sent_review = function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[1])
            wait_for(function()
                return #fake.calls() >= 5
            end)
            return fake.calls()[4][4]
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply(
                'agent list',
                vim.json.encode({
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
            )
            fake.reply('agent prompt', '{}')
            fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
            fake.reply('agent focus', '{}')
            original_cwd = vim.fn.getcwd()
            repo = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(repo, 'p')
            vim.system({ 'git', 'init', '-b', 'main' }, { cwd = repo }):wait()
            vim.cmd.cd(repo)
            vim.fn.writefile({ 'one', 'two', 'three', 'four' }, repo .. '/main.lua')
            vim.fn.writefile({ 'alpha', 'beta' }, repo .. '/a.lua')
        end)

        after_each(function()
            fake.uninstall()
            vim.cmd.cd(original_cwd)
        end)

        it('gives the repo and branch, the location, the excerpt and the comment', function()
            comment_lines(repo .. '/main.lua', 2, 2, 'fix this')

            assert.are.equal(
                table.concat({
                    'Repo: ' .. repo .. ', branch: main',
                    '',
                    'main.lua:2',
                    '```',
                    'two',
                    '```',
                    'fix this',
                    '',
                    'Fix each point. Do not commit.',
                }, '\n'),
                sent_review()
            )
        end)

        it('gives a start-end location for a range and orders notes by path then line', function()
            comment_lines(repo .. '/main.lua', 3, 4, 'late')
            comment_lines(repo .. '/main.lua', 1, 1, 'early')
            comment_lines(repo .. '/a.lua', 2, 2, 'other file')

            assert.are.equal(
                table.concat({
                    'Repo: ' .. repo .. ', branch: main',
                    '',
                    'a.lua:2',
                    '```',
                    'beta',
                    '```',
                    'other file',
                    '',
                    'main.lua:1',
                    '```',
                    'one',
                    '```',
                    'early',
                    '',
                    'main.lua:3-4',
                    '```',
                    'three',
                    'four',
                    '```',
                    'late',
                    '',
                    'Fix each point. Do not commit.',
                }, '\n'),
                sent_review()
            )
        end)

        it('gives absolute paths and no repo line outside a git repository', function()
            comment_lines(repo .. '/main.lua', 2, 2, 'fix this')
            local outside = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(outside, 'p')
            vim.cmd.cd(outside)

            assert.are.equal(
                table.concat({
                    repo .. '/main.lua:2',
                    '```',
                    'two',
                    '```',
                    'fix this',
                    '',
                    'Fix each point. Do not commit.',
                }, '\n'),
                sent_review()
            )
        end)
    end)

    describe('a modified buffer', function()
        local fake
        local path
        local buf

        local wait_for = function(condition)
            assert.is_true(vim.wait(2000, condition, 10))
        end

        local lines = function(first, last)
            local numbered = {}
            for n = first, last do
                table.insert(numbered, 'line ' .. n)
            end

            return numbered
        end

        local choose_agent = function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[1])
        end

        before_each(function()
            fake = fake_herdr.install()
            fake.reply(
                'pane current',
                vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } })
            )
            fake.reply(
                'agent list',
                vim.json.encode({
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
            )
            fake.reply('agent prompt', '{}')
            fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
            fake.reply('agent focus', '{}')
            path = vim.fn.tempname()
            vim.fn.writefile(lines(1, 10), path)
            vim.cmd.edit(path)
            buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf, 0, 3, false, {})
            vim.api.nvim_win_set_cursor(0, { 7, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('fix this', 'tx', false)
            vim.cmd('quit')
        end)

        after_each(function()
            fake.uninstall()
        end)

        it('with a note is saved once an agent is chosen, and the review quotes the saved file', function()
            choose_agent()
            wait_for(function()
                return #fake.calls() >= 5
            end)

            assert.is_false(vim.bo[buf].modified)
            assert.are.same(lines(4, 10), vim.fn.readfile(path))
            local review = fake.calls()[4][4]
            assert.is_truthy(review:find(path .. ':7\n```\nline 10\n```', 1, true))
        end)

        it('without a note is not saved', function()
            local other = vim.fn.tempname()
            vim.fn.writefile(lines(1, 3), other)
            vim.cmd.edit(other)
            local other_buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(other_buf, 0, 1, false, {})
            choose_agent()
            wait_for(function()
                return #fake.calls() >= 5
            end)

            assert.is_true(vim.bo[other_buf].modified)
            assert.are.same(lines(1, 3), vim.fn.readfile(other))
        end)

        it('is not saved when the list is cancelled', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(nil)

            assert.is_true(vim.bo[buf].modified)
            assert.are.same(lines(1, 10), vim.fn.readfile(path))
        end)

        it('that cannot be saved shows the error, sends nothing and keeps the notes', function()
            vim.uv.fs_chmod(path, tonumber('444', 8))
            choose_agent()
            wait_for(function()
                return #messages > 0
            end)

            assert.are.equal(vim.log.levels.ERROR, messages[1].level)
            assert.is_truthy(messages[1].message:find('herdr-review', 1, true))
            assert.are.equal(3, #fake.calls())
            assert.are.equal(2, #vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {}))
        end)
    end)

    describe('without any note', function()
        it('says there is no note to send and opens nothing', function()
            herdr_review.send()

            assert.are.same(
                { 'No note to send' },
                vim.tbl_map(function(m)
                    return m.message
                end, messages)
            )
            assert.are.equal(0, #select_calls)
        end)
    end)
end)
