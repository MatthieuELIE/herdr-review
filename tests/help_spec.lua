local doc_copy = function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. '/doc', 'p')
    vim.fn.writefile(vim.fn.readfile('doc/herdr-review.txt'), root .. '/doc/herdr-review.txt')
    return root
end

describe(':help herdr-review', function()
    it('builds its tags without error', function()
        local root = doc_copy()

        assert.has_no.errors(function()
            vim.cmd.helptags(root .. '/doc')
        end)
    end)

    it('links only to tags that exist', function()
        local root = doc_copy()
        vim.cmd.helptags(root .. '/doc')
        vim.opt.runtimepath:prepend(root)

        local unknown = {}
        for _, line in ipairs(vim.fn.readfile(root .. '/doc/herdr-review.txt')) do
            for tag in line:gmatch('|([^|%s]+)|') do
                if not vim.tbl_contains(vim.fn.getcompletion(tag, 'help'), tag) then
                    table.insert(unknown, tag)
                end
            end
        end

        assert.are.same({}, unknown)
    end)

    it('keeps every line within 78 columns', function()
        local too_long = {}
        for number, line in ipairs(vim.fn.readfile('doc/herdr-review.txt')) do
            if vim.fn.strdisplaywidth(line) > 78 then
                table.insert(too_long, number)
            end
        end

        assert.are.same({}, too_long)
    end)
end)
