local M = {}

local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end

return M
