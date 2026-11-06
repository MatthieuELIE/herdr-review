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
