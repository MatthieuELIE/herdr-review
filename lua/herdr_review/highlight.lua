local M = {}

local tint = 0.15

---@param fg integer
---@param bg integer
---@param shift integer
---@return integer
local blend_channel = function(fg, bg, shift)
    local f = bit.band(bit.rshift(fg, shift), 255)
    local b = bit.band(bit.rshift(bg, shift), 255)
    return bit.lshift(math.floor(f * tint + b * (1 - tint) + 0.5), shift)
end

---@param fg integer
---@param bg integer
---@return integer
local blend = function(fg, bg)
    return blend_channel(fg, bg, 16) + blend_channel(fg, bg, 8) + blend_channel(fg, bg, 0)
end

---@param info? integer text color of DiagnosticInfo
---@param normal? integer background of Normal
---@return table<string, vim.api.keyset.highlight>
local groups_of = function(info, normal)
    if info == nil or normal == nil then
        return {
            HerdrReviewLine = {},
            HerdrReviewNumber = { fg = info },
            HerdrReviewText = { fg = info },
        }
    end

    local background = blend(info, normal)
    return {
        HerdrReviewLine = { bg = background },
        HerdrReviewNumber = { fg = info },
        HerdrReviewText = { fg = info, bg = background },
    }
end

---Sets the note groups from the colors of the current theme.
M.apply = function()
    local info = vim.api.nvim_get_hl(0, { name = 'DiagnosticInfo', link = false }).fg
    local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg
    for name, spec in pairs(groups_of(info, normal)) do
        vim.api.nvim_set_hl(0, name, spec)
    end
end

return M
