local M = {}

M.build = function(notes)
    return table.concat(
        vim.tbl_map(function(note)
            return note.text
        end, notes),
        '\n'
    )
end

return M
