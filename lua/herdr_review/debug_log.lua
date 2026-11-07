local M = {}

---Appends a timestamped line to `herdr-review.log` in Neovim's log directory.
---@param message string
M.write = function(message)
    local dir = vim.fn.stdpath('log')
    vim.fn.mkdir(dir, 'p')

    vim.fn.writefile({ os.date('%Y-%m-%d %H:%M:%S ') .. message }, dir .. '/herdr-review.log', 'a')
end

return M
