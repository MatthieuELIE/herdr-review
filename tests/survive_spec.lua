local fake_herdr = require('tests.support.fake_herdr')
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

---Sends the review through a fake herdr and gives the lines of the note on `buf`'s file, as `3` or `3-4`.
local sent_lines = function(buf)
    local fake = fake_herdr.install()
    fake.reply('pane current', vim.json.encode({ result = { pane = { pane_id = 'w1:p9', workspace_id = 'w1' } } }))
    fake.reply(
        'agent list',
        vim.json.encode({
            result = {
                agents = { { pane_id = 'w1:p1', tab_id = 'w1:t1', workspace_id = 'w1', agent_status = 'idle' } },
            },
        })
    )
    fake.reply('tab list', vim.json.encode({ result = { tabs = { { tab_id = 'w1:t1', label = 'parser' } } } }))
    fake.reply('agent prompt', '{}')
    fake.reply('agent focus', '{}')
    local original_select = vim.ui.select
    vim.ui.select = function(items, _, on_choice)
        on_choice(items[1])
    end

    herdr_review.send()
    local sent = vim.wait(2000, function()
        return #fake.calls() >= 5
    end, 10)
    local prompt = fake.calls()[4][4]
    vim.ui.select = original_select
    fake.uninstall()

    assert.is_true(sent)

    return prompt:match(vim.pesc(vim.api.nvim_buf_get_name(buf)) .. ':(%d+[%-%d]*)\n')
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

        assert.are.same({ 3 }, rows_of(buf, 'number_hl_group'))
        assert.are.same({ 3 }, rows_of(buf, 'line_hl_group'))
        assert.are.same({ 3 }, rows_of(buf, 'virt_lines'))
    end)

    it('follows its lines when lines are removed above it', function()
        local buf = open_file(new_file({ 'one', 'two', 'three' }))
        comment_on(3, 'note')

        vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})

        assert.are.same({ 1 }, rows_of(buf, 'number_hl_group'))
        assert.are.same({ 1 }, rows_of(buf, 'virt_lines'))
    end)

    it('keeps its line numbers current', function()
        local buf = open_file(new_file({ 'one', 'two', 'three' }))
        comment_on(2, 'note')

        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { 'new' })

        assert.are.equal('3', sent_lines(buf))
    end)

    it('reappears on the same lines after :bd and :edit', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(2, 'note')
        vim.cmd('enew')

        vim.cmd.bdelete(buf)
        local reopened = open_file(path)

        assert.are.same({ 1 }, rows_of(reopened, 'number_hl_group'))
        assert.are.same({ 1 }, rows_of(reopened, 'line_hl_group'))
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
        assert.are.same({ 2 }, rows_of(reopened, 'number_hl_group'))
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

        assert.are.same({ 2, 3 }, rows_of(reopened, 'number_hl_group'))
        assert.are.same({ 3 }, rows_of(reopened, 'virt_lines'))
        assert.are.equal('3-4', sent_lines(reopened))
    end)

    it('clamps the note to the last line when the file shrank before reopening', function()
        local path = new_file({ 'one', 'two', 'three' })
        local buf = open_file(path)
        comment_on(3, 'note')
        vim.cmd('enew')
        vim.cmd.bwipeout(buf)
        vim.fn.writefile({ 'one' }, path)

        local reopened = open_file(path)

        assert.are.same({ 0 }, rows_of(reopened, 'number_hl_group'))
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

    it('keeps the notes of several files while switching between them', function()
        local first_path, second_path = new_file({ 'a', 'b' }), new_file({ 'c', 'd' })
        local first = open_file(first_path)
        comment_on(1, 'first')
        local second = open_file(second_path)
        comment_on(2, 'second')

        open_file(first_path)

        assert.are.same({ 0 }, rows_of(first, 'virt_lines'))
        assert.are.same({ 1 }, rows_of(second, 'virt_lines'))
    end)

    it("restores each file's own note after both are closed and reopened", function()
        local first_path, second_path = new_file({ 'a', 'b' }), new_file({ 'c', 'd' })
        local first = open_file(first_path)
        comment_on(1, 'first')
        local second = open_file(second_path)
        comment_on(2, 'second')
        vim.cmd('enew')
        vim.cmd.bwipeout(first)
        vim.cmd.bwipeout(second)

        local reopened_second = open_file(second_path)
        local reopened_first = open_file(first_path)

        assert.are.same({ 1 }, rows_of(reopened_second, 'virt_lines'))
        assert.are.same({ 0 }, rows_of(reopened_first, 'virt_lines'))
    end)

    it('registers no exit autocmd', function()
        for _, event in ipairs({ 'VimLeave', 'VimLeavePre', 'QuitPre' }) do
            assert.are.same({}, vim.api.nvim_get_autocmds({ group = 'herdr_review', event = event }))
        end
    end)
end)
