local M = {}

local namespace = vim.api.nvim_create_namespace('herdr_review')

local virtual_lines_of = function(text)
    return vim.tbl_map(function(line)
        return { { line, 'DiagnosticInfo' } }
    end, vim.split(text, '\n'))
end

M.draw = function(buf, note)
    note.buf = buf
    note.marks = {}
    for line = note.start_line, note.end_line do
        table.insert(
            note.marks,
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                sign_text = '●',
                sign_hl_group = 'DiagnosticSignInfo',
            })
        )
    end
    table.insert(
        note.marks,
        vim.api.nvim_buf_set_extmark(buf, namespace, note.end_line - 1, 0, {
            virt_lines = virtual_lines_of(note.text),
        })
    )
end

M.erase = function(note)
    if not vim.api.nvim_buf_is_valid(note.buf) then
        return
    end
    for _, mark in ipairs(note.marks) do
        vim.api.nvim_buf_del_extmark(note.buf, namespace, mark)
    end
end

return M
