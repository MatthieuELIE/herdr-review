local M = {}

local notes = {}

M.add = function(file, start_line, end_line, text)
    local note = { file = file, start_line = start_line, end_line = end_line, text = text }
    table.insert(notes, note)
    return note
end

return M
