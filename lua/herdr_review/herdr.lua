local M = {}

---@param result vim.SystemCompleted
---@return string message
---@return string? decode_error why stderr is not JSON, nil when it is
local error_message_of = function(result)
    local ok, decoded = pcall(vim.json.decode, result.stderr)
    local plain = 'herdr failed: ' .. vim.trim(result.stderr)
    if not ok then
        return plain, decoded
    end

    if type(decoded) == 'table' and decoded.error then
        return decoded.error.code .. ': ' .. decoded.error.message
    end

    return plain
end

---@param message string
local fail = function(message)
    vim.notify(message, vim.log.levels.ERROR)
end

---Notifies herdr's error, then logs why its stderr is not JSON when it is not.
---@param result vim.SystemCompleted
local report_failure = function(result)
    local message, decode_error = error_message_of(result)
    fail(message)
    if decode_error ~= nil then
        vim.notify('herdr stderr is not JSON: ' .. decode_error, vim.log.levels.DEBUG)
    end
end

---Runs `herdr` and calls `on_ok` with the `result` field of its JSON output, or notifies its error.
---@param args string[]
---@param on_ok fun(result: table)
M.run = function(args, on_ok)
    local started, err = pcall(vim.system, vim.list_extend({ 'herdr' }, args), { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                report_failure(result)

                return
            end

            on_ok(vim.json.decode(result.stdout).result)
        end)
    end)
    if not started then
        fail('herdr could not be run: ' .. err)
    end
end

return M
