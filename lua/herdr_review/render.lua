local M = {}

local namespace = vim.api.nvim_create_namespace('herdr_review')

local virtual_lines_of = function(text)
    return vim.tbl_map(function(line)
        return { { line, 'DiagnosticInfo' } }
    end, vim.split(text, '\n'))
end

M.draw = function(buf, note)
    vim.api.nvim_buf_set_extmark(buf, namespace, note.end_line - 1, 0, {
        virt_lines = virtual_lines_of(note.text),
    })
end

return M
