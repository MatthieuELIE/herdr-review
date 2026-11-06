local M = {}

M.open = function(on_close)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = 60,
        height = 8,
        style = 'minimal',
        border = 'rounded',
    })
    for _, key in ipairs({ '<Esc>', 'q' }) do
        vim.keymap.set('n', key, '<Cmd>close<CR>', { buffer = buf })
    end
    vim.api.nvim_create_autocmd('WinClosed', {
        pattern = tostring(win),
        once = true,
        callback = function()
            on_close(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
        end,
    })
    vim.api.nvim_feedkeys('i', 'ni', false)
end

return M
