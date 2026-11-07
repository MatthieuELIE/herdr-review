---Lines of a file a note covers, or will cover.
---@alias herdr_review.Lines { file: string, start_line: integer, end_line: integer }

local M = {}

local instruction = 'Corrige chaque point. Ne commite pas.'

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

---@param path string
---@param note herdr_review.Note
---@param read_lines fun(file: string, first: integer, last: integer): string[]
---@return string block location, quoted lines and comment of the note
local block_of = function(path, note, read_lines)
    local block = { location_of(path, note), '```' }
    vim.list_extend(block, read_lines(note.file, note.start_line, note.end_line))
    vim.list_extend(block, { '```', note.text })

    return table.concat(block, '\n')
end

---@param root string?
---@param branch string?
---@return string? header nil outside a git repository
local header_of = function(root, branch)
    if root == nil then
        return nil
    end

    return 'Repo : ' .. root .. ', branche : ' .. branch
end

---Builds the text of the review sent to the agent.
---@param notes herdr_review.Note[]
---@param context herdr_review.Context
---@return string
M.build = function(notes, context)
    local entries = vim.tbl_map(function(note)
        return { path = path_of(note, context.root), note = note }
    end, notes)
    table.sort(entries, function(a, b)
        if a.path ~= b.path then
            return a.path < b.path
        end

        return a.note.start_line < b.note.start_line
    end)

    local parts = { header_of(context.root, context.branch) }
    for _, entry in ipairs(entries) do
        table.insert(parts, block_of(entry.path, entry.note, context.read_lines))
    end

    table.insert(parts, instruction)

    return table.concat(parts, '\n\n')
end

return M
