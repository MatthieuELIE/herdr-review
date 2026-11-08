local context = require('herdr_review.context')

---Lines of a file a note covers, or will cover.
---@alias herdr_review.Lines { file: string, start_line: integer, end_line: integer }

local M = {}

local instruction = 'Fix each point. Do not commit.'

---@param note herdr_review.Lines
---@param root string?
---@return string path relative to `root`, absolute outside a git repository
local path_of = function(note, root)
    if root == nil then
        return note.file
    end

    return vim.fs.relpath(root, note.file) or note.file
end

---@param path string
---@param note herdr_review.Lines
---@return string location `path:line` or `path:start-end`
local location_of = function(path, note)
    if note.start_line == note.end_line then
        return path .. ':' .. note.start_line
    end

    return path .. ':' .. note.start_line .. '-' .. note.end_line
end

---Gives the location of the lines as the review writes it.
---@param lines herdr_review.Lines
---@param root string? Git root, nil outside a git repository
---@return string location `path:line` or `path:start-end`
M.location = function(lines, root)
    return location_of(path_of(lines, root), lines)
end

---@param lines string[]
---@return string fence backticks one longer than the longest run in `lines`, three at least
local fence_of = function(lines)
    local longest = 2
    for _, line in ipairs(lines) do
        for run in line:gmatch('`+') do
            longest = math.max(longest, #run)
        end
    end

    return string.rep('`', longest + 1)
end

---@param path string
---@param note herdr_review.Note
---@return string block location, quoted lines and comment of the note
local block_of = function(path, note)
    local lines = context.read_lines(note.file, note.start_line, note.end_line)
    local fence = fence_of(lines)
    local block = { location_of(path, note), fence }
    vim.list_extend(block, lines)
    vim.list_extend(block, { fence, note.text })

    return table.concat(block, '\n')
end

---@param root string?
---@param branch string?
---@return string? header nil outside a git repository
local header_of = function(root, branch)
    if root == nil then
        return nil
    end

    return 'Repo: ' .. root .. ', branch: ' .. branch
end

---Builds the text of the review sent to the agent.
---@param notes herdr_review.Note[]
---@param review_context herdr_review.Context
---@return string
M.build = function(notes, review_context)
    local entries = vim.tbl_map(function(note)
        return { path = path_of(note, review_context.root), note = note }
    end, notes)
    table.sort(entries, function(a, b)
        if a.path ~= b.path then
            return a.path < b.path
        end

        return a.note.start_line < b.note.start_line
    end)

    local parts = { header_of(review_context.root, review_context.branch) }
    for _, entry in ipairs(entries) do
        table.insert(parts, block_of(entry.path, entry.note))
    end

    table.insert(parts, instruction)

    return table.concat(parts, '\n\n')
end

return M
