local M = {}

local instruction = 'Corrige chaque point. Ne commite pas.'

local path_of = function(note, root)
    if root == nil then
        return note.file
    end

    return vim.fs.relpath(root, note.file) or note.file
end

local location_of = function(path, note)
    if note.start_line == note.end_line then
        return path .. ':' .. note.start_line
    end

    return path .. ':' .. note.start_line .. '-' .. note.end_line
end

local block_of = function(path, note, read_lines)
    local block = { location_of(path, note), '```' }
    vim.list_extend(block, read_lines(note.file, note.start_line, note.end_line))
    vim.list_extend(block, { '```', note.text })

    return table.concat(block, '\n')
end

local header_of = function(root, branch)
    if root == nil then
        return nil
    end

    return 'Repo : ' .. root .. ', branche : ' .. branch
end

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
