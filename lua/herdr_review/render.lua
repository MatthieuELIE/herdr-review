local notes = require('herdr_review.notes')

local M = {}

local namespace = vim.api.nvim_create_namespace('herdr_review')

---Under the 199 of mini.diff, whose signs and overlay win over a note.
local priority = 10

---@type table<integer, true> buffers whose edits move their notes
local attached = {}

---@param text string
---@return [string, string][][]
local virtual_lines_of = function(text)
    return vim.tbl_map(function(line)
        return { { '▎ ' .. line, 'HerdrReviewText' } }
    end, vim.split(text, '\n'))
end

---@param note herdr_review.Note
---@param mark integer
---@return integer? row 0-based, nil when the mark is gone
local row_of = function(note, mark)
    return vim.api.nvim_buf_get_extmark_by_id(note.buf, namespace, mark, {})[1]
end

---Moves the note's lines to the rows of its extmarks.
---@param note herdr_review.Note
local sync = function(note)
    local start_row, end_row = row_of(note, note.marks[1]), row_of(note, note.marks[#note.marks])
    if start_row == nil or end_row == nil then
        return
    end

    note.start_line = start_row + 1
    note.end_line = end_row + 1
end

---Keeps the notes of `buf` in sync with its edits, attaching once per buffer.
---@param buf integer
local follow_edits = function(buf)
    if attached[buf] then
        return
    end

    attached[buf] = true
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = function()
            for _, note in ipairs(notes.all()) do
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

---Shows the note in `buf`: each of its lines tinted, its number colored, and its text under the last one.
---@param buf integer
---@param note herdr_review.Note
M.draw = function(buf, note)
    note.buf = buf
    note.marks = {}
    for line = note.start_line, note.end_line do
        table.insert(
            note.marks,
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                line_hl_group = 'HerdrReviewLine',
                number_hl_group = 'HerdrReviewNumber',
                priority = priority,
            })
        )
    end

    table.insert(
        note.marks,
        vim.api.nvim_buf_set_extmark(buf, namespace, note.end_line - 1, 0, {
            virt_lines = virtual_lines_of(note.text),
            priority = priority,
        })
    )

    follow_edits(buf)
end

---@param note herdr_review.Note
M.erase = function(note)
    if not vim.api.nvim_buf_is_valid(note.buf) then
        return
    end

    for _, mark in ipairs(note.marks) do
        vim.api.nvim_buf_del_extmark(note.buf, namespace, mark)
    end
end

---Draws the note again in `buf`, its lines clamped to the buffer's length.
---@param buf integer
---@param note herdr_review.Note
local redraw = function(buf, note)
    if note.buf == buf then
        M.erase(note)
    end

    local last = vim.api.nvim_buf_line_count(buf)
    note.end_line = math.min(note.end_line, last)
    note.start_line = math.min(note.start_line, note.end_line)
    M.draw(buf, note)
end

---Draws the notes of the file of `buf` again once the file is reopened.
---@param buf integer
M.restore = function(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    for _, note in ipairs(notes.all()) do
        if note.file == file then
            redraw(buf, note)
        end
    end
end

return M
