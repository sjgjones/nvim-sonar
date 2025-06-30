local M = {}

local telescope = require("telescope")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local entry_display = require("telescope.make_entry").gen_from_list
local connected_scanner = require("nvim-sonar.connected")

local LOCAL_DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-local")
local CONNECTED_DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("nvim-sonar-connected")

function M.pick_sonar_issues()
  local all_diagnostics = vim.diagnostic.get(0)
  local sonar_diagnostics = {}

  for _, diag in ipairs(all_diagnostics) do
    if diag.namespace == LOCAL_DIAGNOSTIC_NAMESPACE or diag.namespace == CONNECTED_DIAGNOSTIC_NAMESPACE then
      table.insert(sonar_diagnostics, diag)
    end
  end

  local entries = {}
  for _, diag in ipairs(sonar_diagnostics) do
    table.insert(entries, {
      value = diag,
      display = string.format("%s:%d:%d: %s (%s)",
        vim.fn.fnamemodify(vim.api.nvim_buf_get_name(diag.bufnr), ":t"),
        diag.lnum + 1,
        diag.col + 1,
        diag.message,
        diag.code
      ),
      ordinal = string.format("%s %s %s", diag.code, diag.message, vim.api.nvim_buf_get_name(diag.bufnr)),
    })
  end

  pickers.new(conf.defaults.file_sorter, {
    prompt_title = "Sonar Issues",
    finder = finders.new_table(entries),
    previewer = conf.defaults.file_previewer({}),
    sorter = conf.defaults.file_sorter({}),
    entry_display = entry_display({
      separator = " ",
      items = {
        { width = 10 }, -- Severity
        { width = 10 }, -- Code
        { width = 50 }, -- Message
        { width = 20 }, -- File:Line
      },
    }),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        local selection = telescope.get_selected_entry(prompt_bufnr)
        if selection then
          local diag = selection.value
          vim.api.nvim_win_set_cursor(0, { diag.lnum + 1, diag.col })
          telescope.close(prompt_bufnr)
        end
      end)
      return true
    end,
  }):find()
end

function M.pick_sonar_rules()
  connected_scanner.fetch_rules(function(rules)
    local entries = {}
    for _, rule in ipairs(rules) do
      table.insert(entries, {
        value = rule,
        display = string.format("%s: %s", rule.key, rule.name),
        ordinal = string.format("%s %s", rule.key, rule.name),
      })
    end

    pickers.new(conf.defaults.file_sorter, {
      prompt_title = "Sonar Rules",
      finder = finders.new_table(entries),
      previewer = conf.defaults.buffer_previewer({
        define_preview = function(self, entry)
          local rule_key = entry.value.key
          connected_scanner.fetch_rule_details(rule_key, function(rule_details)
            if rule_details then
              local lines = {}
              table.insert(lines, "Rule: " .. rule_details.name)
              table.insert(lines, "Key: " .. rule_details.key)
              table.insert(lines, "Severity: " .. rule_details.severity)
              table.insert(lines, "Status: " .. rule_details.status)
              table.insert(lines, "\nDescription:")
              table.insert(lines, rule_details.htmlDesc)
              table.insert(lines, "\nWhy it is an issue:")
              table.insert(lines, rule_details.htmlDesc)
              table.insert(lines, "\nHow to fix:")
              table.insert(lines, rule_details.htmlDesc)

              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            else
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Failed to load rule details."})
            end
          end)
        end,
      }),
      sorter = conf.defaults.file_sorter({}),
      entry_display = entry_display({
        separator = " ",
        items = {
          { width = 20 }, -- Rule Key
          { width = 60 }, -- Rule Name
        },
      }),
    }):find()
  end)
end

return M
