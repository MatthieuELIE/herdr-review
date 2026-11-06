describe('herdr_review.setup', function()
    local herdr_review = require('herdr_review')

    it('runs without option and defaults the agent to claude', function()
        assert.has_no.errors(function()
            herdr_review.setup()
        end)
        assert.are.equal('claude', herdr_review.config.agent)
    end)

    it('accepts an agent option', function()
        assert.has_no.errors(function()
            herdr_review.setup({ agent = 'copilot' })
        end)
        assert.are.equal('copilot', herdr_review.config.agent)
    end)

    it('creates no mapping and no command', function()
        local mappings = #vim.api.nvim_get_keymap('n') + #vim.api.nvim_get_keymap('x')
        local commands = vim.tbl_count(vim.api.nvim_get_commands({}))

        herdr_review.setup()

        assert.are.equal(mappings, #vim.api.nvim_get_keymap('n') + #vim.api.nvim_get_keymap('x'))
        assert.are.equal(commands, vim.tbl_count(vim.api.nvim_get_commands({})))
    end)

    it('returns to the default agent when setup is called again without option', function()
        herdr_review.setup({ agent = 'copilot' })
        herdr_review.setup()
        assert.are.equal('claude', herdr_review.config.agent)
    end)
end)
