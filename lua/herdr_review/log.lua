local M = {}

---Creates the file `<stamp>.md` in `dir`, suffixing `-1`, `-2`... to the stamp while the name is taken.
---@param dir string
---@param stamp string
---@return integer fd
local create_unused = function(dir, stamp)
    local suffix = 0
    while true do
        local name = stamp
        if suffix > 0 then
            name = stamp .. '-' .. suffix
        end

        local fd, err, code = vim.uv.fs_open(dir .. '/' .. name .. '.md', 'wx', tonumber('600', 8))
        if fd then
            return fd
        end

        assert(code == 'EEXIST', err)
        suffix = suffix + 1
    end
end

---Writes the review to a new file of the review log.
---@param text string
---@param root string? Git root naming the repo's folder, the working directory's name outside a repository
M.archive = function(text, root)
    local dir = vim.fn.stdpath('state') .. '/herdr-review/' .. vim.fs.basename(root or vim.fn.getcwd())
    vim.fn.mkdir(dir, 'p', '0700')

    local fd = create_unused(dir, os.date('%Y-%m-%d-%H%M%S') --[[@as string]])
    vim.uv.fs_write(fd, text)
    vim.uv.fs_close(fd)
end

return M
