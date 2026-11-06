local M = {}

local notes = {}

M.add = function(file, start_line, end_line, text)
    local note = { file = file, start_line = start_line, end_line = end_line, text = text }
    table.insert(notes, note)
    return note
end

M.all = function()
    return vim.list_slice(notes)
end

M.remove = function(removed)
    notes = vim.tbl_filter(function(note)
        return not vim.list_contains(removed, note)
    end, notes)
end

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
