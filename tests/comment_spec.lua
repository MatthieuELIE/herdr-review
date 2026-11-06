local herdr_review = require('herdr_review')

local floating_windows = function()
    return vim.tbl_filter(function(win)
        return vim.api.nvim_win_get_config(win).relative ~= ''
    end, vim.api.nvim_list_wins())
end

local open_file = function(lines)
    local path = vim.fn.tempname()
    vim.fn.writefile(lines, path)
    vim.cmd.edit(path)
    return vim.api.nvim_get_current_buf()
end

describe('herdr_review.comment', function()
    before_each(function()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
    end)

    describe('in normal mode', function()
        it('opens a floating window in insert mode', function()
            open_file({ 'one', 'two', 'three' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })

            herdr_review.comment()

            assert.are.equal(1, #floating_windows())
            vim.api.nvim_feedkeys('hello', 'tx', false)
            assert.are.same({ 'hello' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        end)
    end)
end)
