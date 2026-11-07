local float = require('herdr_review.float')
local notes = require('herdr_review.notes')
local render = require('herdr_review.render')

local M = {}

local save_new = function(target, text)
    local note = notes.add(target.file, target.start_line, target.end_line, text)
    render.draw(target.buf, note)
end

local save_correction = function(note, text)
    render.erase(note)
    note.text = text
    render.draw(note.buf, note)
end

local delete = function(note)
    render.erase(note)
    notes.remove({ note })
end

local save = function(target, text)
    local trimmed = vim.trim(text)
    if trimmed == '' and target.note then
        return delete(target.note)
    end

    if trimmed == '' then
        return
    end

    if target.note then
        return save_correction(target.note, trimmed)
    end

    save_new(target, trimmed)
end

local note_to_reopen = function(visual, file, line)
    if visual then
        return nil
    end

    return notes.closest_above(file, line)
end

local text_of = function(note)
    if note == nil then
        return nil
    end

    return note.text
end

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
