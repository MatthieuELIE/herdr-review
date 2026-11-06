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
                        workspace_id = 'w1',
                        agent_status = 'idle',
                        terminal_title_stripped = 'Fix the parser',
                    },
                    {
                        pane_id = 'w2:p1',
                        workspace_id = 'w2',
                        agent_status = 'working',
                        terminal_title_stripped = 'Other project',
                    },
                    {
                        pane_id = 'w1:p2',
                        workspace_id = 'w1',
                        agent_status = 'working',
                        terminal_title_stripped = 'Write the docs',
                    },
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

        it('lists the agents of the nvim workspace with their title and status', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)

            local call = select_calls[1]
            assert.are.equal(2, #call.items)
            assert.are.equal('Fix the parser (idle)', call.opts.format_item(call.items[1]))
            assert.are.equal('Write the docs (working)', call.opts.format_item(call.items[2]))
        end)

        it('sends the review to the chosen agent with herdr agent prompt', function()
            herdr_review.send()
            wait_for(function()
                return #select_calls > 0
            end)
            select_calls[1].on_choice(select_calls[1].items[2])
            wait_for(function()
                return #fake.calls() >= 3
            end)

            local prompt = fake.calls()[3]
            assert.are.same({ 'agent', 'prompt', 'w1:p2' }, vim.list_slice(prompt, 1, 3))
            assert.is_truthy(prompt[4]:find('fix this', 1, true))
        end)
    end)

    describe('without any note', function()
        it('says there is no note to send and opens nothing', function()
            herdr_review.send()

            assert.are.same(
                { 'Aucune note à envoyer' },
                vim.tbl_map(function(m)
                    return m.message
                end, messages)
            )
            assert.are.equal(0, #select_calls)
        end)
    end)
end)
