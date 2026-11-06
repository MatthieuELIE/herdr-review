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

local virtual_lines_marks = function(buf)
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    return vim.tbl_filter(function(mark)
        return mark[4].virt_lines ~= nil
    end, marks)
end

local sign_rows = function(buf)
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    local rows = {}
    for _, mark in ipairs(marks) do
        if mark[4].sign_text ~= nil then
            table.insert(rows, mark[2])
        end
    end
    return rows
end

local texts_of = function(virt_lines)
    return vim.tbl_map(function(chunks)
        return chunks[1][1]
    end, virt_lines)
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

        it('saves the note as virtual lines under the line when the window is quit with :q', function()
            local buf = open_file({ 'one', 'two', 'three' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })

            herdr_review.comment()
            vim.api.nvim_feedkeys('fix this', 'tx', false)
            vim.cmd('quit')

            local marks = virtual_lines_marks(buf)
            assert.are.equal(1, #marks)
            assert.are.equal(1, marks[1][2])
            assert.are.same({ 'fix this' }, texts_of(marks[1][4].virt_lines))
        end)
    end)

    describe('floating window', function()
        local note_texts_after = function(keys)
            local buf = open_file({ 'one', 'two', 'three' })
            herdr_review.comment()
            vim.api.nvim_feedkeys(vim.keycode(keys), 'tx', false)
            local marks = virtual_lines_marks(buf)
            if #marks == 0 then
                return {}
            end
            return texts_of(marks[1][4].virt_lines)
        end

        it('accepts several lines of text', function()
            assert.are.same({ 'first', 'second' }, note_texts_after('first<CR>second<Esc><Esc>'))
        end)

        it('saves the note when quit with <Esc> in normal mode', function()
            assert.are.same({ 'note' }, note_texts_after('note<Esc><Esc>'))
        end)

        it('drops the blank lines around the text', function()
            assert.are.same({ 'note' }, note_texts_after('note<CR><Esc><Esc>'))
        end)

        it('creates nothing when closed empty', function()
            assert.are.same({}, note_texts_after('<Esc><Esc>'))
        end)

        it('saves the note when quit with q', function()
            assert.are.same({ 'note' }, note_texts_after('note<Esc>q'))
        end)
    end)

    describe('in visual mode', function()
        local comment_on_selection = function(keys, text)
            vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)
            vim.api.nvim_feedkeys(keys .. vim.keycode('<Leader>') .. 'ac' .. text, 'tx', false)
        end

        it('opens a floating window in insert mode', function()
            open_file({ 'one', 'two', 'three' })

            comment_on_selection('Vj', 'hello')

            assert.are.equal(1, #floating_windows())
            assert.are.same({ 'hello' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        end)

        it('saves a note on every selected line', function()
            local buf = open_file({ 'one', 'two', 'three', 'four' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })

            comment_on_selection('Vj', 'fix these')
            vim.cmd('quit')

            assert.are.same({ 1, 2 }, sign_rows(buf))
            local marks = virtual_lines_marks(buf)
            assert.are.equal(1, #marks)
            assert.are.equal(2, marks[1][2])
        end)
    end)
end)
