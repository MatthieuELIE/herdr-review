local herdr_review = require('herdr_review')

local open_file = function(lines)
    local path = vim.fn.tempname()
    vim.fn.writefile(lines, path)
    vim.cmd.edit(path)
    return vim.api.nvim_get_current_buf()
end

local marks_with = function(buf, field)
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    return vim.tbl_filter(function(mark)
        return mark[4][field] ~= nil
    end, marks)
end

local note_texts = function(buf)
    return vim.tbl_map(function(mark)
        return mark[4].virt_lines[1][1][1]
    end, marks_with(buf, 'virt_lines'))
end

local sign_rows = function(buf)
    return vim.tbl_map(function(mark)
        return mark[2]
    end, marks_with(buf, 'sign_text'))
end

local floating_text = function()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local note_on = function(line, text)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    herdr_review.comment()
    vim.api.nvim_feedkeys(text, 'tx', false)
    vim.cmd('quit')
end

local note_on_selection = function(first, last, text)
    vim.api.nvim_win_set_cursor(0, { first, 0 })
    vim.api.nvim_feedkeys('V' .. (last - first) .. 'j', 'tx', false)
    herdr_review.comment()
    vim.api.nvim_feedkeys(text, 'tx', false)
    vim.cmd('quit')
end

describe('herdr_review.comment on a covered line', function()
    before_each(function()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
    end)

    it('reopens the note with its text and saves the correction', function()
        local buf = open_file({ 'one', 'two', 'three' })
        note_on(2, 'fix this')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        assert.are.same({ 'fix this' }, floating_text())
        vim.api.nvim_feedkeys(vim.keycode('<Esc>ccbetter'), 'tx', false)
        vim.cmd('quit')

        assert.are.same({ 'better' }, note_texts(buf))
        assert.are.same({ 1 }, sign_rows(buf))
    end)

    it('reopens a note from any line it covers', function()
        open_file({ 'one', 'two', 'three', 'four' })
        note_on_selection(2, 3, 'range')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()

        assert.are.same({ 'range' }, floating_text())
    end)

    it('reopens the note that starts closest above the line', function()
        local buf = open_file({ 'one', 'two', 'three', 'four', 'five' })
        note_on_selection(1, 5, 'outer')
        note_on_selection(2, 4, 'middle')
        note_on_selection(3, 5, 'inner')

        vim.api.nvim_win_set_cursor(0, { 4, 0 })
        herdr_review.comment()
        assert.are.same({ 'inner' }, floating_text())
        vim.cmd('quit')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        assert.are.same({ 'middle' }, floating_text())
        vim.cmd('quit')
        assert.are.equal(3, #note_texts(buf))
    end)
end)
