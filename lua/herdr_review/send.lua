local agents = require('herdr_review.agents')
local context = require('herdr_review.context')
local herdr = require('herdr_review.herdr')
local log = require('herdr_review.log')
local notes = require('herdr_review.notes')
local render = require('herdr_review.render')
local review = require('herdr_review.review')

local M = {}

local archive = function(text, root)
    local archived, err = pcall(log.archive, text, root)
    if not archived then
        vim.notify('herdr-review: ' .. err, vim.log.levels.ERROR)
    end
end

local clear = function(review_notes)
    notes.remove(review_notes)
    vim.tbl_map(render.erase, review_notes)
end

local deliver = function(pane_id, review_notes, review_context)
    local text = review.build(review_notes, review_context)

    herdr.run({ 'agent', 'prompt', pane_id, text }, function()
        herdr.run({ 'agent', 'focus', pane_id }, function() end)
        clear(review_notes)
        archive(text, review_context.root)
    end)
end

local start_agent = function(workspace_id, cwd, kind, on_started)
    herdr.run({ 'tab', 'create', '--workspace', workspace_id, '--cwd', cwd, '--focus' }, function(created)
        local pane_id = created.root_pane.pane_id

        herdr.run({ 'agent', 'start', os.date('review-%H%M%S'), '--kind', kind, '--pane', pane_id }, function()
            on_started(pane_id)
        end)
    end)
end

local send_to = function(choice, review_notes, workspace_id, kind)
    if choice == nil then
        return
    end

    local review_context = context.current()
    if not agents.is_new(choice) then
        return deliver(choice.pane_id, review_notes, review_context)
    end

    start_agent(workspace_id, review_context.root or vim.fn.getcwd(), kind, function(pane_id)
        deliver(pane_id, review_notes, review_context)
    end)
end

local choose_in_workspace = function(workspace_id, on_choice)
    herdr.run({ 'agent', 'list' }, function(listed)
        agents.choose(agents.in_workspace(listed.agents, workspace_id), on_choice)
    end)
end

M.send = function(kind)
    local review_notes = notes.all()
    if #review_notes == 0 then
        vim.notify('Aucune note à envoyer')

        return
    end

    herdr.run({ 'pane', 'current' }, function(current)
        local workspace_id = current.pane.workspace_id

        choose_in_workspace(workspace_id, function(choice)
            send_to(choice, review_notes, workspace_id, kind)
        end)
    end)
end

return M
