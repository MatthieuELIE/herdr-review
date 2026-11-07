---@class herdr_review.Context
---@field root string? Git root, nil outside a git repository
---@field branch string?
---@field read_lines fun(file: string, first: integer, last: integer): string[]

local M = {}

---@param args string[]
---@return string? output trimmed stdout, nil when git fails
local git_output = function(args)
    local result = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
    if result.code ~= 0 then
        return nil
    end

    return vim.trim(result.stdout)
end

---Reads lines of the file from its loaded buffer, or from disk when it has none.
---@param file string
---@param first integer
---@param last integer
---@return string[]
local read_lines = function(file, first, last)
    local buf = vim.fn.bufnr(file)
    if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
        return vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
    end

    return vim.list_slice(vim.fn.readfile(file), first, last)
end

---@return herdr_review.Context
M.current = function()
    return {
        root = git_output({ 'rev-parse', '--show-toplevel' }),
        branch = git_output({ 'branch', '--show-current' }),
        read_lines = read_lines,
    }
end

return M
