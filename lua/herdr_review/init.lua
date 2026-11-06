local M = {}

local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end

M.comment = function()
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    require('herdr_review.float').open(function(text)
        local note = require('herdr_review.notes').add(file, line, line, text)
        require('herdr_review.render').draw(buf, note)
    end)
end

return M
