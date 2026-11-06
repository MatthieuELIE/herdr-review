local M = {}

local create_unused = function(dir, stamp)
    local suffix = 0
    while true do
        local name = stamp
        if suffix > 0 then
            name = stamp .. '-' .. suffix
        end
        local fd, err, code = vim.uv.fs_open(dir .. '/' .. name .. '.md', 'wx', 420)
        if fd then
            return fd
        end
        assert(code == 'EEXIST', err)
        suffix = suffix + 1
    end
end

M.archive = function(text, root)
    local dir = vim.fn.stdpath('state') .. '/herdr-review/' .. vim.fs.basename(root or vim.fn.getcwd())
    vim.fn.mkdir(dir, 'p')
    local fd = create_unused(dir, os.date('%Y-%m-%d-%H%M%S'))
    vim.uv.fs_write(fd, text)
    vim.uv.fs_close(fd)
end

return M
