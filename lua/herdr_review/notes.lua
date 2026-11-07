---@class herdr_review.Note
---@field file string
---@field start_line integer
---@field end_line integer
---@field text string
---@field buf integer buffer the note is drawn in
---@field marks integer[] extmark ids of the note in `buf`

local M = {}

---@type herdr_review.Note[]
local notes = {}

---@param file string
---@param start_line integer
---@param end_line integer
---@param text string
---@return herdr_review.Note
M.add = function(file, start_line, end_line, text)
    local note = { file = file, start_line = start_line, end_line = end_line, text = text }
    table.insert(notes, note)

    return note
end

---@return herdr_review.Note[] copy of the list of notes
M.all = function()
    return vim.list_slice(notes)
end

---@param removed herdr_review.Note[]
M.remove = function(removed)
    notes = vim.tbl_filter(function(note)
        return not vim.list_contains(removed, note)
    end, notes)
end

---Finds, among the notes of `file` covering `line`, the one that starts closest above it.
---@param file string
---@param line integer
---@return herdr_review.Note?
M.closest_above = function(file, line)
    local closest
    for _, note in ipairs(notes) do
        local covers = note.file == file and note.start_line <= line and line <= note.end_line
        if covers and (closest == nil or note.start_line >= closest.start_line) then
            closest = note
        end
    end

    return closest
end

return M
