local M = {}

local config = require("nvim-sonar.config")

local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-connected")

local function map_severity(sonar_severity)
  sonar_severity = sonar_severity:upper()
  if sonar_severity == "BLOCKER" then
    return vim.diagnostic.severity.ERROR
  elseif sonar_severity == "CRITICAL" then
    return vim.diagnostic.severity.ERROR
  elseif sonar_severity == "MAJOR" then
    return vim.diagnostic.severity.WARN
  elseif sonar_severity == "MINOR" then
    return vim.diagnostic.severity.INFO
  elseif sonar_severity == "INFO" then
    return vim.diagnostic.severity.HINT
  else
    return vim.diagnostic.severity.INFO
  end
end

local function display_diagnostics(filepath, issues)
  local diagnostics = {}
  for _, issue in ipairs(issues) do
    table.insert(diagnostics, {
      bufnr = vim.uri_to_bufnr(filepath),
      lnum = issue.textRange.startLine - 1, -- Neovim is 0-indexed
      col = issue.textRange.startOffset,
      end_lnum = issue.textRange.endLine - 1,
      end_col = issue.textRange.endOffset,
      severity = map_severity(issue.severity),
      message = issue.message,
      source = "SonarQube",
      code = issue.rule,
    })
  end
  vim.diagnostic.set(DIAGNOSTIC_NAMESPACE, vim.uri_to_bufnr(filepath), diagnostics)
end

function M.run_scan(filepath)
  local sonarqube_url = config.options.sonarqube_url
  local sonarqube_token = config.options.sonarqube_token

  if not sonarqube_url or sonarqube_url == "" then
    vim.notify("nvim-sonar: sonarqube_url is not configured.", vim.log.levels.ERROR)
    return
  end
  if not sonarqube_token or sonarqube_token == "" then
    vim.notify("nvim-sonar: sonarqube_token is not configured.", vim.log.levels.ERROR)
    return
  end

  -- Clear existing diagnostics for the file
  vim.diagnostic.set(DIAGNOSTIC_NAMESPACE, vim.uri_to_bufnr(filepath), {})

  -- This is a simplified example. In a real scenario, you'd need to map the local filepath
  -- to the componentKey used in SonarQube/SonarCloud.
  -- For now, let's assume the filepath is directly usable as a componentKey.
  local component_key = filepath

  local url = string.format("%s/api/issues/search?componentKeys=%s", sonarqube_url, vim.uri_encode(component_key))
  local headers = {
    ["Authorization"] = "Bearer " .. sonarqube_token,
    ["Accept"] = "application/json",
  }

  vim.fn.jobstart({"curl", "-s", "-H", "Authorization: Bearer " .. sonarqube_token, url}, {
    on_stdout = function(_, data, _)
      local output = table.concat(data, "\n")
      local success, result = pcall(vim.fn.json_decode, output)
      if success and result and result.issues then
        display_diagnostics(filepath, result.issues)
      else
        vim.notify("nvim-sonar: Failed to parse SonarQube API output or no issues found.", vim.log.levels.WARN)
      end
    end,
    on_stderr = function(_, data, _)
      vim.notify("nvim-sonar: SonarQube API Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
    end,
    on_exit = function(job_id, code, _)
      if code ~= 0 then
        vim.notify("nvim-sonar: SonarQube API call exited with code " .. code, vim.log.levels.WARN)
      end
    end,
    rpc = false,
  })
end

function M.fetch_rules(callback)
  local sonarqube_url = config.options.sonarqube_url
  local sonarqube_token = config.options.sonarqube_token

  if not sonarqube_url or sonarqube_url == "" then
    vim.notify("nvim-sonar: sonarqube_url is not configured.", vim.log.levels.ERROR)
    callback({})
    return
  end
  if not sonarqube_token or sonarqube_token == "" then
    vim.notify("nvim-sonar: sonarqube_token is not configured.", vim.log.levels.ERROR)
    callback({})
    return
  end

  local url = string.format("%s/api/rules/search?p=1&ps=500", sonarqube_url) -- Fetch up to 500 rules

  vim.fn.jobstart({"curl", "-s", "-H", "Authorization: Bearer " .. sonarqube_token, url}, {
    on_stdout = function(_, data, _)
      local output = table.concat(data, "\n")
      local success, result = pcall(vim.fn.json_decode, output)
      if success and result and result.rules then
        callback(result.rules)
      else
        vim.notify("nvim-sonar: Failed to fetch rules or parse SonarQube API output.", vim.log.levels.WARN)
        callback({})
      end
    end,
    on_stderr = function(_, data, _)
      vim.notify("nvim-sonar: SonarQube API Error fetching rules: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
      callback({})
    end,
    on_exit = function(job_id, code, _)
      if code ~= 0 then
        vim.notify("nvim-sonar: SonarQube API call for rules exited with code " .. code, vim.log.levels.WARN)
        callback({})
      end
    end,
    rpc = false,
  })
end

function M.fetch_rule_details(rule_key, callback)
  local sonarqube_url = config.options.sonarqube_url
  local sonarqube_token = config.options.sonarqube_token

  if not sonarqube_url or sonarqube_url == "" or not sonarqube_token or sonarqube_token == "" then
    callback("Configuration missing.")
    return
  end

  local url = string.format("%s/api/rules/show?key=%s", sonarqube_url, vim.uri_encode(rule_key))

  vim.fn.jobstart({"curl", "-s", "-H", "Authorization: Bearer " .. sonarqube_token, url}, {
    on_stdout = function(_, data, _)
      local output = table.concat(data, "\n")
      local success, result = pcall(vim.fn.json_decode, output)
      if success and result and result.rule then
        callback(result.rule)
      else
        vim.notify("nvim-sonar: Failed to fetch rule details or parse SonarQube API output.", vim.log.levels.WARN)
        callback(nil)
      end
    end,
    on_stderr = function(_, data, _)
      vim.notify("nvim-sonar: SonarQube API Error fetching rule details: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
      callback(nil)
    end,
    on_exit = function(job_id, code, _)
      if code ~= 0 then
        vim.notify("nvim-sonar: SonarQube API call for rule details exited with code " .. code, vim.log.levels.WARN)
        callback(nil)
      end
    end,
    rpc = false,
  })
end

return M