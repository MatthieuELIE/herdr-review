local M = {}

---Opens the note window in insert mode, filled with `text` when given and the cursor at its end.
---@param on_close fun(text: string) called with the window's text when it closes
---@param text string?
---@param title string
M.open = function(on_close, text, title)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    if text ~= nil then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n'))
    end

    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = 60,
        height = 8,
        style = 'minimal',
        border = 'rounded',
        title = title,
    })

    for _, key in ipairs({ '<Esc>', 'q', '<CR>' }) do
        vim.keymap.set('n', key, '<Cmd>close<CR>', { buffer = buf })
    end

    vim.keymap.set('i', '<CR>', '<Esc><Cmd>close<CR>', { buffer = buf })

    vim.api.nvim_create_autocmd('WinClosed', {
        pattern = tostring(win),
        once = true,
        callback = function()
            on_close(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
        end,
    })

    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
    vim.api.nvim_feedkeys('A', 'ni', false)
end

return M
