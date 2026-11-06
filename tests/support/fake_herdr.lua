local M = {}

local script = [[#!/bin/sh
dir=$(dirname "$0")/..
n=$(ls "$dir/calls" | wc -l | tr -d ' ')
printf '%s\0' "$@" > "$dir/calls/$n"
key="$1-$2"
code=0
if [ -f "$dir/out/$key.code" ]; then
  code=$(cat "$dir/out/$key.code")
fi
if [ "$code" = 0 ]; then
  cat "$dir/out/$key.json"
else
  cat "$dir/out/$key.json" >&2
fi
exit "$code"
]]

local read_file = function(path)
    local file = assert(io.open(path, 'rb'))
    local content = file:read('*a')
    file:close()
    return content
end

M.install = function()
    local root = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(root .. '/bin', 'p')
    vim.fn.mkdir(root .. '/calls', 'p')
    vim.fn.mkdir(root .. '/out', 'p')
    vim.fn.writefile(vim.split(script, '\n'), root .. '/bin/herdr')
    vim.uv.fs_chmod(root .. '/bin/herdr', tonumber('755', 8))
    local original_path = vim.env.PATH
    vim.env.PATH = root .. '/bin:' .. original_path

    local fake = {}

    fake.reply = function(command, json, code)
        local key = command:gsub(' ', '-')
        vim.fn.writefile({ json }, root .. '/out/' .. key .. '.json')
        vim.fn.writefile({ tostring(code or 0) }, root .. '/out/' .. key .. '.code')
    end

    fake.calls = function()
        local names = vim.fn.readdir(root .. '/calls')
        table.sort(names, function(a, b)
            return tonumber(a) < tonumber(b)
        end)
        local calls = {}
        for _, name in ipairs(names) do
            local content = read_file(root .. '/calls/' .. name)
            if content ~= '' then
                table.insert(calls, vim.split(content, '\0', { plain = true, trimempty = true }))
            end
        end
        return calls
    end

    fake.uninstall = function()
        vim.env.PATH = original_path
    end

    return fake
end

return M
