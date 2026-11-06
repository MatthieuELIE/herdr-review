local M = {}

local namespace = vim.api.nvim_create_namespace('herdr_review')

local attached = {}

local virtual_lines_of = function(text)
    return vim.tbl_map(function(line)
        return { { line, 'DiagnosticInfo' } }
    end, vim.split(text, '\n'))
end

local row_of = function(note, mark)
    return vim.api.nvim_buf_get_extmark_by_id(note.buf, namespace, mark, {})[1]
end

local sync = function(note)
    note.start_line = row_of(note, note.marks[1]) + 1
    note.end_line = row_of(note, note.marks[#note.marks]) + 1
end

local follow_edits = function(buf)
    if attached[buf] then
        return
    end
    attached[buf] = true
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = function()
            for _, note in ipairs(require('herdr_review.notes').all()) do
                if note.buf == buf then
                    sync(note)
                end
            end
        end,
        on_detach = function()
            attached[buf] = nil
        end,
    })
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
    follow_edits(buf)
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
