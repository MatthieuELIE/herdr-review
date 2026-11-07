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
        return (mark[4].virt_lines[1][1][1]:gsub('^▎ ', ''))
    end, marks_with(buf, 'virt_lines'))
end

local number_rows = function(buf)
    return vim.tbl_map(function(mark)
        return mark[2]
    end, marks_with(buf, 'number_hl_group'))
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
    vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)
    local select = vim.keycode('<Esc>') .. 'V' .. (last - first) .. 'j'
    vim.api.nvim_feedkeys(select .. vim.keycode('<Leader>') .. 'ac' .. text, 'tx', false)
    vim.cmd('quit')
end

describe('herdr_review.comment on a covered line', function()
    before_each(function()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
    end)

    after_each(function()
        assert.are.equal(0, vim.fn.getchar(1))
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
        assert.are.same({ 1 }, number_rows(buf))
    end)

    it('reopens the note in insert mode at the end of its last line', function()
        open_file({ 'one', 'two', 'three' })
        note_on(2, 'first' .. vim.keycode('<S-CR>') .. 'second')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys(' more', 'tx', false)

        assert.are.same({ 'first', 'second more' }, floating_text())
        vim.cmd('quit')
    end)

    it('reopens a note from any line it covers', function()
        open_file({ 'one', 'two', 'three', 'four' })
        note_on_selection(2, 3, 'range')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys('', 'tx', false)

        assert.are.same({ 'range' }, floating_text())
        vim.cmd('quit')
    end)

    it('reopens the note that starts closest above the line', function()
        local buf = open_file({ 'one', 'two', 'three', 'four', 'five' })
        note_on_selection(1, 5, 'outer')
        note_on_selection(2, 4, 'middle')
        note_on_selection(3, 5, 'inner')

        vim.api.nvim_win_set_cursor(0, { 4, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys('', 'tx', false)
        assert.are.same({ 'inner' }, floating_text())
        vim.cmd('quit')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys('', 'tx', false)
        assert.are.same({ 'middle' }, floating_text())
        vim.cmd('quit')
        assert.are.equal(3, #note_texts(buf))
    end)

    it('deletes the note, its line numbers and its virtual lines when the window is emptied', function()
        local buf = open_file({ 'one', 'two', 'three', 'four' })
        note_on_selection(2, 3, 'range')
        note_on(1, 'other')

        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys(vim.keycode('<Esc>cc'), 'tx', false)
        vim.cmd('quit')

        assert.are.same({ 'other' }, note_texts(buf))
        assert.are.same({ 0 }, number_rows(buf))
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys('', 'tx', false)
        assert.are.same({ '' }, floating_text())
    end)

    it('deletes the note when the emptied window is closed with <CR>', function()
        local buf = open_file({ 'one', 'two', 'three' })
        note_on(2, 'fix this')

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys(vim.keycode('<Esc>cc<CR>'), 'tx', false)

        assert.are.same({}, note_texts(buf))
        assert.are.same({}, number_rows(buf))
    end)

    it('saves the correction of a note whose buffer was wiped out and reopened', function()
        local buf = open_file({ 'one', 'two', 'three' })
        local path = vim.api.nvim_buf_get_name(buf)
        note_on(2, 'fix this')
        vim.cmd('enew')
        vim.cmd.bwipeout(buf)
        vim.cmd.edit(path)
        local reopened = vim.api.nvim_get_current_buf()

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        herdr_review.comment()
        vim.api.nvim_feedkeys(vim.keycode('<Esc>ccbetter'), 'tx', false)
        vim.cmd('quit')

        assert.are.same({ 'better' }, note_texts(reopened))
        assert.are.same({ 1 }, number_rows(reopened))
    end)
end)
