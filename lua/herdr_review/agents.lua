---An agent as `herdr agent list` reports it.
---@class herdr_review.Agent
---@field pane_id string
---@field workspace_id string
---@field terminal_title_stripped string
---@field agent_status string

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
        return 'Nouvel agent'
    end

    return string.format('%s (%s)', agent.terminal_title_stripped, agent.agent_status)
end

---@param agents herdr_review.Agent[]
---@param on_choice fun(choice: herdr_review.Choice?)
M.choose = function(agents, on_choice)
    vim.ui.select(
        vim.list_extend({ new_agent }, agents),
        { prompt = 'Envoyer la review à', format_item = M.format },
        on_choice
    )
end

return M
