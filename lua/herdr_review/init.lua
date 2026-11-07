local M = {}

local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})

    vim.api.nvim_create_autocmd('BufReadPost', {
        group = vim.api.nvim_create_augroup('herdr_review', { clear = true }),
        callback = function(args)
            require('herdr_review.render').restore(args.buf)
        end,
    })
end

M.comment = function()
    require('herdr_review.comment').open()
end

M.send = function()
    require('herdr_review.send').send(M.config.agent)
end

return M
