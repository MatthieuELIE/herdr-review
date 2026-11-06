local herdr_review = require('herdr_review')

local open_file = function(path)
    vim.cmd.edit(path)
    return vim.api.nvim_get_current_buf()
end

local new_file = function(lines)
    local path = vim.fn.tempname()
    vim.fn.writefile(lines, path)
    return path
end

local comment_on = function(line, text)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    herdr_review.comment()
    vim.api.nvim_feedkeys(text, 'tx', false)
    vim.cmd('quit')
end

local rows_of = function(buf, detail)
    local rows = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
        if mark[4][detail] ~= nil then
            table.insert(rows, mark[2])
        end
    end
    return rows
end

describe('a note across edits', function()
    before_each(function()
        herdr_review.setup()
        vim.cmd('silent! %bwipeout!')
    end)

    it('follows its lines when lines are added above it', function()
        local buf = open_file(new_file({ 'one', 'two', 'three' }))
        comment_on(2, 'note')

        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { 'new a', 'new b' })

        assert.are.same({ 3 }, rows_of(buf, 'sign_text'))
        assert.are.same({ 3 }, rows_of(buf, 'virt_lines'))
    end)

    it('follows its lines when lines are removed above it', function()
        local buf = open_file(new_file({ 'one', 'two', 'three' }))
        comment_on(3, 'note')

        vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})

        assert.are.same({ 1 }, rows_of(buf, 'sign_text'))
        assert.are.same({ 1 }, rows_of(buf, 'virt_lines'))
    end)

    it('keeps its line numbers current', function()
        local buf = open_file(new_file({ 'one', 'two', 'three' }))
        comment_on(2, 'note')

        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { 'new' })

        local all = require('herdr_review.notes').all()
        local note = all[#all]
        assert.are.equal(3, note.start_line)
        assert.are.equal(3, note.end_line)
    end)

    it('reappears on the same lines after :bd and :edit', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(2, 'note')
        vim.cmd('enew')

        vim.cmd.bdelete(buf)
        local reopened = open_file(path)

        assert.are.same({ 1 }, rows_of(reopened, 'sign_text'))
        assert.are.same({ 1 }, rows_of(reopened, 'virt_lines'))
    end)

    it('reappears in a new buffer after :bwipeout and :edit', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(3, 'note')
        vim.cmd('enew')

        vim.cmd.bwipeout(buf)
        local reopened = open_file(path)

        assert.are_not.equal(buf, reopened)
        assert.are.same({ 2 }, rows_of(reopened, 'sign_text'))
    end)

    it('reappears on every line of a multi-line note and follows later edits', function()
        local path = new_file({ 'one', 'two', 'three', 'four' })
        local buf = open_file(path)
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.cmd('normal! Vj')
        vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)
        vim.api.nvim_feedkeys(vim.keycode('<Leader>') .. 'acnote', 'tx', false)
        vim.cmd('quit')
        vim.cmd('enew')
        vim.cmd.bwipeout(buf)

        local reopened = open_file(path)
        vim.api.nvim_buf_set_lines(reopened, 0, 0, false, { 'new' })

        assert.are.same({ 2, 3 }, rows_of(reopened, 'sign_text'))
        assert.are.same({ 3 }, rows_of(reopened, 'virt_lines'))
        local all = require('herdr_review.notes').all()
        assert.are.equal(3, all[#all].start_line)
        assert.are.equal(4, all[#all].end_line)
    end)

    it('clamps the note to the last line when the file shrank before reopening', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(3, 'note')
        vim.cmd('enew')
        vim.cmd.bwipeout(buf)
        vim.fn.writefile({ 'one' }, path)

        local reopened = open_file(path)

        assert.are.same({ 0 }, rows_of(reopened, 'sign_text'))
        assert.are.same({ 0 }, rows_of(reopened, 'virt_lines'))
    end)

    it('reappears once only after several :bd and :edit', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(2, 'note')
        vim.cmd('enew')
        vim.cmd.bdelete(buf)
        local reopened = open_file(path)
        vim.cmd('enew')
        vim.cmd.bdelete(reopened)

        local again = open_file(path)

        assert.are.same({ 1 }, rows_of(again, 'virt_lines'))
    end)

    it('registers no exit autocmd', function()
        for _, event in ipairs({ 'VimLeave', 'VimLeavePre', 'QuitPre' }) do
            assert.are.same({}, vim.api.nvim_get_autocmds({ group = 'herdr_review', event = event }))
        end
    end)
end)
