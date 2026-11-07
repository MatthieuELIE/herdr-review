local agents = require('herdr_review.agents')
local context = require('herdr_review.context')
local herdr = require('herdr_review.herdr')
local log = require('herdr_review.log')
local notes = require('herdr_review.notes')
local render = require('herdr_review.render')
local review = require('herdr_review.review')

local M = {}

---Writes the review to the review log, and notifies the error when that fails.
---@param text string
---@param root string?
local archive = function(text, root)
    local archived, err = pcall(log.archive, text, root)
    if not archived then
        vim.notify('herdr-review: ' .. err, vim.log.levels.ERROR)
    end
end

---Removes the notes from the list and from their buffers.
---@param review_notes herdr_review.Note[]
local clear = function(review_notes)
    notes.remove(review_notes)
    vim.tbl_map(render.erase, review_notes)
end

---Sends the review to the agent of `pane_id`, then focuses it, clears the notes and archives the review.
---@param pane_id string
---@param review_notes herdr_review.Note[]
---@param review_context herdr_review.Context
local deliver = function(pane_id, review_notes, review_context)
    local text = review.build(review_notes, review_context)

    herdr.run({ 'agent', 'prompt', pane_id, text }, function()
        herdr.run({ 'agent', 'focus', pane_id }, function() end)
        clear(review_notes)
        archive(text, review_context.root)
    end)
end

---Starts an agent of `kind` in a new tab of the workspace.
---@param workspace_id string
---@param cwd string
---@param kind string
---@param on_started fun(pane_id: string)
local start_agent = function(workspace_id, cwd, kind, on_started)
    herdr.run({ 'tab', 'create', '--workspace', workspace_id, '--cwd', cwd, '--focus' }, function(created)
        local pane_id = created.root_pane.pane_id
        local name = os.date('review-%H%M%S') --[[@as string]]

        herdr.run({ 'agent', 'start', name, '--kind', kind, '--pane', pane_id }, function()
            on_started(pane_id)
        end)
    end)
end

---Sends the review to the chosen agent, starting it first when it is a new one.
---@param choice herdr_review.Choice? nil when the list is cancelled
---@param review_notes herdr_review.Note[]
---@param workspace_id string
---@param kind string
local send_to = function(choice, review_notes, workspace_id, kind)
    if choice == nil then
        return
    end

    local review_context = context.current()
    if not agents.is_new(choice) then
        deliver(choice.pane_id, review_notes, review_context)

        return
    end

    start_agent(workspace_id, review_context.root or vim.fn.getcwd(), kind, function(pane_id)
        deliver(pane_id, review_notes, review_context)
    end)
end

---@param workspace_id string
---@param on_choice fun(choice: herdr_review.Choice?)
local choose_in_workspace = function(workspace_id, on_choice)
    herdr.run({ 'agent', 'list' }, function(listed)
        agents.choose(agents.in_workspace(listed.agents, workspace_id), on_choice)
    end)
end

---Lets the user pick an agent of their Herdr workspace and sends it the review.
---@param kind string agent kind started when the user picks a new agent
M.send = function(kind)
    local review_notes = notes.all()
    if #review_notes == 0 then
        vim.notify('No note to send')

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
