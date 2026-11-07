---An agent as `herdr agent list` reports it, with the label of its tab once `with_tab_labels` adds it.
---@class herdr_review.Agent
---@field pane_id string
---@field tab_id string
---@field workspace_id string
---@field agent_status string
---@field tab_label string?

---A tab as `herdr tab list` reports it.
---@class herdr_review.Tab
---@field tab_id string
---@field label string

---An entry of the agent list: an agent, or the entry that starts a new one.
---@alias herdr_review.Choice herdr_review.Agent|{ new: true }

local M = {}

---@param agents herdr_review.Agent[]
---@param workspace_id string
---@return herdr_review.Agent[]
M.in_workspace = function(agents, workspace_id)
    return vim.tbl_filter(function(agent)
        return agent.workspace_id == workspace_id
    end, agents)
end

---@param agents herdr_review.Agent[]
---@param tabs herdr_review.Tab[]
---@return herdr_review.Agent[]
M.with_tab_labels = function(agents, tabs)
    local labels = {}
    for _, tab in ipairs(tabs) do
        labels[tab.tab_id] = tab.label
    end

    return vim.tbl_map(function(agent)
        return vim.tbl_extend('force', agent, { tab_label = labels[agent.tab_id] })
    end, agents)
end

local new_agent = { new = true }

---@param choice herdr_review.Choice
---@return boolean
M.is_new = function(choice)
    return choice.new == true
end

---@param agent herdr_review.Choice
---@return string
M.format = function(agent)
    if M.is_new(agent) then
        return 'New agent'
    end

    return string.format('%s (%s)', agent.tab_label, agent.agent_status)
end

---@param agents herdr_review.Agent[]
---@param on_choice fun(choice: herdr_review.Choice?)
M.choose = function(agents, on_choice)
    vim.ui.select(
        vim.list_extend(vim.list_slice(agents), { new_agent }),
        { prompt = 'Send the review to', format_item = M.format },
        on_choice
    )
end

return M
