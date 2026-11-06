local M = {}

M.open = function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = 60,
        height = 8,
        style = 'minimal',
        border = 'rounded',
    })
    vim.api.nvim_feedkeys('i', 'n', false)
end

return M
