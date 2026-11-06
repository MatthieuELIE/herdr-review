local M = {}

local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end

M.comment = function()
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local anchor, cursor = vim.fn.line('v'), vim.fn.line('.')
    local start_line, end_line = math.min(anchor, cursor), math.max(anchor, cursor)
    if vim.fn.mode():find('[vV\22]') then
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end
    require('herdr_review.float').open(function(text)
        local note = require('herdr_review.notes').add(file, start_line, end_line, text)
        require('herdr_review.render').draw(buf, note)
    end)
end

return M
