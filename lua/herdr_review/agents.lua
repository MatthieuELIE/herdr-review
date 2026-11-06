local M = {}

M.in_workspace = function(agents, workspace_id)
    return vim.tbl_filter(function(agent)
        return agent.workspace_id == workspace_id
    end, agents)
end

local new_agent = { new = true }

M.is_new = function(choice)
    return choice.new == true
end

M.format = function(agent)
    if M.is_new(agent) then
        return 'Nouvel agent'
    end
    return string.format('%s (%s)', agent.terminal_title_stripped, agent.agent_status)
end

M.choose = function(agents, on_choice)
    vim.ui.select(
        vim.list_extend({ new_agent }, agents),
        { prompt = 'Envoyer la review à', format_item = M.format },
        on_choice
    )
end

return M
