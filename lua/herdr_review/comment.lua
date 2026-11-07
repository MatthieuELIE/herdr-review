local float = require('herdr_review.float')
local notes = require('herdr_review.notes')
local render = require('herdr_review.render')

---Where the note window writes: the cursor line or the selected lines.
---@class herdr_review.Target
---@field buf integer
---@field file string
---@field start_line integer
---@field end_line integer
---@field note herdr_review.Note? note to correct, nil for a new one

local M = {}

---@param target herdr_review.Target
---@param text string
local save_new = function(target, text)
    local note = notes.add(target.file, target.start_line, target.end_line, text)
    render.draw(target.buf, note)
end

---@param note herdr_review.Note
---@param text string
local save_correction = function(note, text)
    render.erase(note)
    note.text = text
    render.draw(note.buf, note)
end

---@param note herdr_review.Note
local delete = function(note)
    render.erase(note)
    notes.remove({ note })
end

---Saves the window's text as a new note or a correction, or deletes the note when the text is empty.
---@param target herdr_review.Target
---@param text string
local save = function(target, text)
    local trimmed = vim.trim(text)
    if trimmed == '' and target.note then
        delete(target.note)

        return
    end

    if trimmed == '' then
        return
    end

    if target.note then
        save_correction(target.note, trimmed)

        return
    end

    save_new(target, trimmed)
end

---@param visual boolean
---@param file string
---@param line integer
---@return herdr_review.Note? note nil in visual mode or when no note covers `line`
local note_to_reopen = function(visual, file, line)
    if visual then
        return nil
    end

    return notes.closest_above(file, line)
end

---@param note herdr_review.Note?
---@return string?
local text_of = function(note)
    if note == nil then
        return nil
    end

    return note.text
end

---@param visual boolean
---@return herdr_review.Target
local target_at_cursor = function(visual)
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local anchor, cursor = vim.fn.line('v'), vim.fn.line('.')

    return {
        buf = buf,
        file = file,
        start_line = math.min(anchor, cursor),
        end_line = math.max(anchor, cursor),
        note = note_to_reopen(visual, file, cursor),
    }
end

---Opens the note window for the cursor line, or for the selected lines in visual mode.
M.open = function()
    local visual = vim.fn.mode():find('[vV\22]') ~= nil
    local target = target_at_cursor(visual)
    if visual then
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end

    float.open(function(text)
        save(target, text)
    end, text_of(target.note))
end

return M
