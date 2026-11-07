---@class herdr_review.Config
---@field agent string kind passed to `herdr agent start --kind`

local M = {}

---@type herdr_review.Config
local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

---@param opts? { agent?: string }
M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})
    require('herdr_review.highlight').apply()

    vim.api.nvim_create_autocmd('BufReadPost', {
        group = vim.api.nvim_create_augroup('herdr_review', { clear = true }),
        callback = function(args)
            require('herdr_review.render').restore(args.buf)
        end,
    })
end

---Opens the note window for the cursor line, or for the selected lines in visual mode.
M.comment = function()
    require('herdr_review.comment').open()
end

---Lets the user pick an agent of their Herdr workspace and sends it the review.
M.send = function()
    require('herdr_review.send').send(M.config.agent)
end

return M
