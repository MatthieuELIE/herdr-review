local M = {}

local error_message_of = function(result)
    local ok, decoded = pcall(vim.json.decode, result.stderr)
    if ok and type(decoded) == 'table' and decoded.error then
        return decoded.error.code .. ': ' .. decoded.error.message
    end

    return 'herdr failed: ' .. vim.trim(result.stderr)
end

local fail = function(message)
    vim.notify(message, vim.log.levels.ERROR)
end

M.run = function(args, on_ok)
    local started, err = pcall(vim.system, vim.list_extend({ 'herdr' }, args), { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                return fail(error_message_of(result))
            end

            on_ok(vim.json.decode(result.stdout).result)
        end)
    end)
    if not started then
        fail('herdr could not be run: ' .. err)
    end
end

return M
