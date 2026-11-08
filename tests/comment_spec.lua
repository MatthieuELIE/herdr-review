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

local number_rows = function(buf)
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    local rows = {}
    for _, mark in ipairs(marks) do
        if mark[4].number_hl_group ~= nil then
            table.insert(rows, mark[2])
        end
    end
    return rows
end

local texts_of = function(virt_lines)
    return vim.tbl_map(function(chunks)
        return (chunks[1][1]:gsub('^▎ ', ''))
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

        it('breaks the line on <S-CR>', function()
            assert.are.same({ 'first', 'second' }, note_texts_after('first<S-CR>second<Esc><Esc>'))
        end)

        it('saves the note when quit with <Esc> in normal mode', function()
            assert.are.same({ 'note' }, note_texts_after('note<Esc><Esc>'))
        end)

        it('drops the blank lines around the text', function()
            assert.are.same({ 'note' }, note_texts_after('note<S-CR><Esc><Esc>'))
        end)

        it('creates nothing when closed empty', function()
            assert.are.same({}, note_texts_after('<Esc><Esc>'))
        end)

        it('saves the note when quit with q', function()
            assert.are.same({ 'note' }, note_texts_after('note<Esc>q'))
        end)

        it('saves the note and closes the window on <CR> in insert mode', function()
            assert.are.same({ 'note' }, note_texts_after('note<CR>'))
            assert.are.equal(0, #floating_windows())
        end)

        it('saves the note and closes the window on <CR> in normal mode', function()
            assert.are.same({ 'note' }, note_texts_after('note<Esc><CR>'))
            assert.are.equal(0, #floating_windows())
        end)

        it('creates nothing on <CR> in an empty window', function()
            assert.are.same({}, note_texts_after('<CR>'))
        end)
    end)

    describe('note display', function()
        local comment_on_line_two = function()
            local buf = open_file({ 'one', 'two', 'three' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            herdr_review.comment()
            vim.api.nvim_feedkeys('note', 'tx', false)
            vim.cmd('quit')
            return buf
        end

        local marks_of = function(buf)
            return vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
        end

        it('leaves the buffer unmodified', function()
            local buf = comment_on_line_two()
            assert.is_false(vim.bo[buf].modified)
            assert.are.same({ 'one', 'two', 'three' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        end)

        it('tints each line of the note and colors its number, with no sign', function()
            local buf = open_file({ 'one', 'two', 'three', 'four' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)
            vim.api.nvim_feedkeys('Vj' .. vim.keycode('<Leader>') .. 'ac' .. 'note', 'tx', false)
            vim.cmd('quit')

            local tinted = {}
            for _, mark in ipairs(marks_of(buf)) do
                local details = mark[4]
                assert.is_nil(details.sign_text)
                if details.line_hl_group ~= nil then
                    assert.are.equal('HerdrReviewLine', details.line_hl_group)
                    assert.are.equal('HerdrReviewNumber', details.number_hl_group)
                    table.insert(tinted, mark[2])
                end
            end

            assert.are.same({ 1, 2 }, tinted)
        end)

        it('prefixes each line of the text with a bar, in the text group', function()
            local buf = open_file({ 'one', 'two', 'three' })
            herdr_review.comment()
            vim.api.nvim_feedkeys(vim.keycode('first<S-CR>second<CR>'), 'tx', false)

            assert.are.same({
                { { '▎ first', 'HerdrReviewText' } },
                { { '▎ second', 'HerdrReviewText' } },
            }, virtual_lines_marks(buf)[1][4].virt_lines)
        end)

        it('stays under the priority 199 of mini.diff', function()
            local buf = comment_on_line_two()
            for _, mark in ipairs(marks_of(buf)) do
                assert.is_true(mark[4].priority < 199)
            end
        end)

        it('shows in every window displaying the file', function()
            local buf = comment_on_line_two()
            vim.cmd.split()
            assert.are.equal(2, #vim.fn.win_findbuf(buf))
            assert.are.equal(1, #virtual_lines_marks(buf))
            assert.is_nil(virtual_lines_marks(buf)[1][4].scoped)
            assert.are.same({ 1 }, number_rows(buf))
        end)
    end)

    describe('on a buffer with no file', function()
        local original_notify = vim.notify
        local messages

        before_each(function()
            messages = {}
            vim.notify = function(message, level)
                table.insert(messages, { message = message, level = level })
            end
        end)

        after_each(function()
            vim.notify = original_notify
        end)

        it('opens no window and warns that the buffer needs a file', function()
            vim.cmd.enew()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two' })

            herdr_review.comment()

            assert.are.equal(0, #floating_windows())
            assert.are.same({
                { message = 'herdr-review: save the buffer to a file to leave a note', level = vim.log.levels.WARN },
            }, messages)
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

            assert.are.same({ 1, 2 }, number_rows(buf))
            local marks = virtual_lines_marks(buf)
            assert.are.equal(1, #marks)
            assert.are.equal(2, marks[1][2])
        end)
    end)

    describe('window title', function()
        local original_cwd
        local repo

        before_each(function()
            original_cwd = vim.fn.getcwd()
            repo = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(repo, 'p')
            vim.system({ 'git', 'init', '-b', 'main' }, { cwd = repo }):wait()
            vim.cmd.cd(repo)
            vim.fn.writefile({ 'one', 'two', 'three' }, repo .. '/main.lua')
            vim.cmd.edit(repo .. '/main.lua')
        end)

        after_each(function()
            vim.cmd('quit')
            vim.cmd.cd(original_cwd)
        end)

        local title_of_window = function()
            vim.api.nvim_feedkeys('', 'tx', false)

            return vim.api.nvim_win_get_config(0).title[1][1]
        end

        it('gives the line relative to the repo root', function()
            vim.api.nvim_win_set_cursor(0, { 2, 0 })

            herdr_review.comment()

            assert.are.equal(' Review note · main.lua:2 ', title_of_window())
        end)

        it('gives the selected range relative to the repo root', function()
            vim.keymap.set({ 'n', 'x' }, '<Leader>ac', herdr_review.comment)

            vim.api.nvim_feedkeys('Vj' .. vim.keycode('<Leader>') .. 'ac', 'tx', false)

            assert.are.equal(' Review note · main.lua:1-2 ', title_of_window())
        end)

        it('gives the absolute path outside a git repository', function()
            local outside = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(outside, 'p')
            vim.cmd.cd(outside)

            herdr_review.comment()

            assert.are.equal(' Review note · ' .. repo .. '/main.lua:1 ', title_of_window())
        end)
    end)
end)
