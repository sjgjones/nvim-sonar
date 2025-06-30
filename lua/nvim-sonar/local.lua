local M = {}

local config = require("nvim-sonar.config")

local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-local")

local function display_diagnostics(filepath, issues)
  local diagnostics = {}
  for _, issue in ipairs(issues) do
    table.insert(diagnostics, {
      bufnr = vim.uri_to_bufnr(filepath),
      lnum = issue.textRange.startLine - 1, -- Neovim is 0-indexed
      col = issue.textRange.startLineOffset,
      end_lnum = issue.textRange.endLine - 1,
      end_col = issue.textRange.endLineOffset,
      severity = vim.diagnostic.severity[issue.severity:upper()],
      message = issue.message,
      source = "SonarLint",
      code = issue.ruleId,
    })
  end
  vim.diagnostic.set(DIAGNOSTIC_NAMESPACE, vim.uri_to_bufnr(filepath), diagnostics)
end

function M.run_scan(filepath)
  local sonarlint_cli_path = config.options.sonarlint_cli_path
  if not sonarlint_cli_path or sonarlint_cli_path == "" then
    vim.notify("nvim-sonar: sonarlint_cli_path is not configured.", vim.log.levels.ERROR)
    return
  end

  -- Clear existing diagnostics for the file
  vim.diagnostic.set(DIAGNOSTIC_NAMESPACE, vim.uri_to_bufnr(filepath), {})

  local cmd = string.format("%s -f json %s", sonarlint_cli_path, vim.fn.shellescape(filepath))

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      local output = table.concat(data, "\n")
      local success, result = pcall(vim.fn.json_decode, output)
      if success and result and result.issues then
        display_diagnostics(filepath, result.issues)
      else
        vim.notify("nvim-sonar: Failed to parse SonarLint CLI output or no issues found.", vim.log.levels.WARN)
      end
    end,
    on_stderr = function(_, data, _)
      vim.notify("nvim-sonar: SonarLint CLI Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
    end,
    on_exit = function(job_id, code, _)
      if code ~= 0 then
        vim.notify("nvim-sonar: SonarLint CLI exited with code " .. code, vim.log.levels.WARN)
      end
    end,
    rpc = false,
  })
end

return M