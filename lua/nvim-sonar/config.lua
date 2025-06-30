local M = {}

M.options = {
  -- "connected" or "local"
  mode = "local",

  -- "live" or "on_demand"
  scan_mode = "on_demand",

  -- SonarQube/SonarCloud settings (for connected mode)
  sonarqube_url = "",
  sonarqube_token = "",

  -- SonarLint CLI path (for local mode)
  sonarlint_cli_path = "",
}

return M
