local M = {}

local LOCAL_DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-local")
local CONNECTED_DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-connected")

function M.sonar_diagnostics()
  local local_diagnostics = vim.diagnostic.get(0, { namespace = LOCAL_DIAGNOSTIC_NAMESPACE })
  local connected_diagnostics = vim.diagnostic.get(0, { namespace = CONNECTED_DIAGNOSTIC_NAMESPACE })

  local count = #local_diagnostics + #connected_diagnostics

  if count > 0 then
    return { " Sonar: ", count, " " }
  else
    return nil
  end
end

return M