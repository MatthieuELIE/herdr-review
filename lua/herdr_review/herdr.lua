local debug_log = require('herdr_review.debug_log')

local M = {}

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

local fail = function(message)
    vim.notify(message, vim.log.levels.ERROR)
end

local report_failure = function(result)
    local message, decode_error = error_message_of(result)
    fail(message)
    if decode_error ~= nil then
        debug_log.write('herdr stderr is not JSON: ' .. decode_error)
    end
end

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
