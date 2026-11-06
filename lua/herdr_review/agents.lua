local M = {}

M.in_workspace = function(agents, workspace_id)
    return vim.tbl_filter(function(agent)
        return agent.workspace_id == workspace_id
    end, agents)
end

M.format = function(agent)
    return string.format('%s (%s)', agent.terminal_title_stripped, agent.agent_status)
end

M.choose = function(agents, on_choice)
    vim.ui.select(agents, { prompt = 'Envoyer la review à', format_item = M.format }, on_choice)
end

return M
