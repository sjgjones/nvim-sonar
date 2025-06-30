local M = {}

local config = require("nvim-sonar.config")
local local_scanner = require("nvim-sonar.local")
local connected_scanner = require("nvim-sonar.connected")

-- Check if telescope is available before requiring telescope functionality
local has_telescope, telescope_picker = pcall(require, "nvim-sonar.telescope")
if not has_telescope then
  telescope_picker = nil
end

local heirline_components = require("nvim-sonar.heirline")

local function scan_current_buffer()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath and filepath ~= "" then
    if config.options.mode == "local" then
      local_scanner.run_scan(filepath)
    elseif config.options.mode == "connected" then
      connected_scanner.run_scan(filepath)
    end
  end
end

local function setup_whichkey()
  if not pcall(require, "which-key") then
    vim.notify("nvim-sonar: WhichKey is not installed or not loaded. Skipping WhichKey integration.", vim.log.levels.INFO)
    return
  end

  local wk = require("which-key")
  local keymaps = {
    s = {
      name = "Sonar",
      S = { ":SonarScan<CR>", "[S]can Current Buffer" },
    },
  }
  
  -- Only add telescope keymaps if telescope is available
  if telescope_picker then
    keymaps.s.t = { ":SonarTelescope<CR>", "[T]elescope Issues" }
    keymaps.s.r = { ":SonarRules<CR>", "[R]ules" }
  end
  
  wk.register(keymaps, { prefix = "," })
end

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})

  -- Setup autocommands for live scanning if enabled
  if config.options.scan_mode == "live" then
    vim.api.nvim_create_autocmd({"BufWritePost", "InsertLeave"}, {
      pattern = "*",
      callback = scan_current_buffer,
    })
  end

  -- Expose commands
  vim.api.nvim_create_user_command("SonarScan", scan_current_buffer, { desc = "Run Sonar scan on current buffer" })
  
  -- Only create telescope commands if telescope is available
  if telescope_picker then
    vim.api.nvim_create_user_command("SonarTelescope", telescope_picker.pick_sonar_issues, { desc = "Open Telescope picker for Sonar issues" })
    vim.api.nvim_create_user_command("SonarRules", telescope_picker.pick_sonar_rules, { desc = "Open Telescope picker for Sonar rules" })
  end

  setup_whichkey()
end

function M.get_heirline_component()
  return heirline_components.sonar_diagnostics
end

return M
