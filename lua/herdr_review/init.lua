local M = {}

local defaults = { agent = 'claude' }

M.config = vim.deepcopy(defaults)

M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end

M.comment = function()
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local anchor, cursor = vim.fn.line('v'), vim.fn.line('.')
    local start_line, end_line = math.min(anchor, cursor), math.max(anchor, cursor)
    if vim.fn.mode():find('[vV\22]') then
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end
    require('herdr_review.float').open(function(text)
        local trimmed = vim.trim(text)
        if trimmed == '' then
            return
        end
        local note = require('herdr_review.notes').add(file, start_line, end_line, trimmed)
        require('herdr_review.render').draw(buf, note)
    end)
end

M.send = function()
    local notes = require('herdr_review.notes').all()
    if #notes == 0 then
        vim.notify('Aucune note à envoyer')
        return
    end
    local herdr = require('herdr_review.herdr')
    local agents = require('herdr_review.agents')
    herdr.run({ 'pane', 'current' }, function(current)
        herdr.run({ 'agent', 'list' }, function(listed)
            local candidates = agents.in_workspace(listed.agents, current.pane.workspace_id)
            agents.choose(candidates, function(choice)
                if choice == nil then
                    return
                end
                local context = require('herdr_review.context').current()
                local deliver = function(pane_id)
                    local review = require('herdr_review.review')
                    herdr.run({ 'agent', 'prompt', pane_id, review.build(notes, context) }, function()
                        herdr.run({ 'agent', 'focus', pane_id }, function() end)
                        require('herdr_review.notes').remove(notes)
                        vim.tbl_map(require('herdr_review.render').erase, notes)
                    end)
                end
                if not agents.is_new(choice) then
                    return deliver(choice.pane_id)
                end
                herdr.run({
                    'tab',
                    'create',
                    '--workspace',
                    current.pane.workspace_id,
                    '--cwd',
                    context.root or vim.fn.getcwd(),
                    '--focus',
                }, function(created)
                    local pane_id = created.root_pane.pane_id
                    herdr.run({
                        'agent',
                        'start',
                        os.date('review-%H%M%S'),
                        '--kind',
                        M.config.agent,
                        '--pane',
                        pane_id,
                    }, function()
                        deliver(pane_id)
                    end)
                end)
            end)
        end)
    end)
end

return M
