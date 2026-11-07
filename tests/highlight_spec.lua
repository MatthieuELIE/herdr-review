local herdr_review = require('herdr_review')

local group = function(name)
    return vim.api.nvim_get_hl(0, { name = name })
end

describe('note colors', function()
    after_each(function()
        vim.cmd('silent! highlight clear')
    end)

    it('tint the lines and the text with 15% of the DiagnosticInfo text color over the Normal background', function()
        vim.api.nvim_set_hl(0, 'DiagnosticInfo', { fg = 0x64c8ff })
        vim.api.nvim_set_hl(0, 'Normal', { fg = 0xffffff, bg = 0x141414 })

        herdr_review.setup()

        assert.are.same({ bg = 0x202f37 }, group('HerdrReviewLine'))
        assert.are.same({ fg = 0x64c8ff }, group('HerdrReviewNumber'))
        assert.are.same({ fg = 0x64c8ff, bg = 0x202f37 }, group('HerdrReviewText'))
    end)

    it('leave the lines and the text untinted when Normal has no background', function()
        vim.api.nvim_set_hl(0, 'DiagnosticInfo', { fg = 0x64c8ff })
        vim.api.nvim_set_hl(0, 'Normal', { fg = 0xffffff })

        herdr_review.setup()

        assert.are.same({}, group('HerdrReviewLine'))
        assert.are.same({ fg = 0x64c8ff }, group('HerdrReviewNumber'))
        assert.are.same({ fg = 0x64c8ff }, group('HerdrReviewText'))
    end)
end)
