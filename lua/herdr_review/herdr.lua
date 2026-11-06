local M = {}

M.run = function(args, on_done)
    vim.system(vim.list_extend({ 'herdr' }, args), { text = true }, function(result)
        vim.schedule(function()
            on_done(vim.json.decode(result.stdout).result)
        end)
    end)
end

return M
