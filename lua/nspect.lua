---@diagnostic disable: undefined-global

local RSpecParser = require("rspec_parser")

local M = {}

M.setup = function()
  M.reset_state()
  M.plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*)/lua(.*)$")
  M.spec_runs = {}
  M.win_title = "NSpect 🧪"
  M.win_title_state = "Idle"
  M.wins = {}

  vim.keymap.set("n", "<leader>R", M.reload_plugin)
  vim.keymap.set("n", "<leader>F", M.run_file)
  vim.keymap.set("n", "<leader>H", M.run_line)
  vim.keymap.set("n", "<leader>G", M.run_previous)
  vim.keymap.set("n", "<leader>O", M.open_prev_run)

  M.highlight_ns_id = vim.api.nvim_create_namespace("NSpectHighlight")
  vim.api.nvim_set_hl(0, "NSpectGreen", {
    fg = "#00F000",
  })
  vim.api.nvim_set_hl(0, "NSpectRed", {
    fg = "#F00000",
  })
  vim.api.nvim_set_hl(0, "NSpectYellow", {
    fg = "#F0F000",
  })
end

M.reload_plugin = function()
  package.loaded["nspect"] = nil
  package.loaded["rspec_parser"] = nil
  RSpecParser = require("rspec_parser")
  local plug = require("nspect")
  plug.setup()
  print("Reloading NSpect")
end

M.reset_state = function()
  M.notifications = {}
  M.example_noti_count = 0
  M.win_title_state = "Executing"
  M.run_spec_count = nil
  M.error_data = ""
end

M.run_file = function()
  M.reset_state()

  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local cmd, cmd_args = M.build_command("file", filepath, nil)

  local run = {
    cmd = cmd,
    cmd_args = cmd_args,
    notifications = {},
  }
  table.insert(M.spec_runs, 1, run)

  M.execute_run(1)
end

M.run_line = function()
  M.reset_state()

  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local cmd, cmd_args = M.build_command("line", filepath, line_number)

  local run = {
    cmd = cmd,
    cmd_args = cmd_args,
    notifications = {},
  }
  table.insert(M.spec_runs, 1, run)

  M.execute_run(1)
end

M.build_command = function(type, filepath, line_number)
  local cmd
  local use_bundle = vim.fn.filereadable(vim.fn.getcwd().."/".."Gemfile") == 1
  local command_file_part = filepath

  if type == "line" then
    command_file_part = command_file_part .. ":" .. line_number
  end

  local cmd_args = {
    command_file_part,
    "--require",
    M.plugin_root .. "/rspec_formatter/jsonl_formatter.rb",
    "--format",
    "NSpect::JSONLFormatter",
  }

  if use_bundle then
    cmd = "bundle"
    table.insert(cmd_args, 1, "rspec")
    table.insert(cmd_args, 1, "exec")
  else
    cmd = "rspec"
  end

  return cmd, cmd_args
end

M.run_previous = function()
  if #M.spec_runs < 1 then return end

  M.reset_state()
  local prev_run = M.spec_runs[1]
  local run = {
    cmd = prev_run.cmd,
    cmd_args = prev_run.cmd_args,
    notifications = {},
  }
  table.insert(M.spec_runs, 1, run)

  M.execute_run(1)
end

M.run_highlighted_spec = function()
  M.reset_state()

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local current_line = vim.api.nvim_buf_get_lines(0, cursor_line-1, cursor_line, false)[1]

  local parts = {}
  for part in current_line:gmatch("([^%-]+)") do
    table.insert(parts, part:match("^%s*(.-)%s*$")) -- Trim spaces
  end
  local selected_id = tonumber(parts[1])

  for _, notification in ipairs(M.spec_runs[1].notifications) do
    if notification.id == selected_id then
      local cmd, cmd_args = M.build_command("line", notification.full_filepath, notification.line_number)

      local run = {
        cmd = cmd,
        cmd_args = cmd_args,
        notifications = {},
      }
      table.insert(M.spec_runs, 1, run)

      M.execute_run(1)
      return
    end
  end
end

M.execute_run = function(run_index)
  local run = M.spec_runs[run_index]
  local bufnr, win = M.create_run_buf()
  local cmd = run.cmd
  local cmd_args = run.cmd_args

  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  vim.uv.spawn(cmd, {
    args = cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    vim.schedule(function()
      if M.error_data == "" then
        M.win_title_state = "Ran " .. run.spec_count .. " specs"
      else
        M.win_title_state = "Failed to run"
      end
      M.redraw_buff(bufnr, win, run)
    end)
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        if notification.type == "start" then
          run.spec_count = notification.spec_count
          M.win_title_state = "Running " .. run.spec_count .. " specs"
        else
          notification.id = M.example_noti_count
          M.example_noti_count = M.example_noti_count + 1
        end
        table.insert(run.notifications, notification)
      end
      M.redraw_buff(bufnr, win, run)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end
    M.error_data = M.error_data .. data

    vim.schedule(function()
      M.redraw_buff(bufnr, win, run)
    end)
  end)
end

local split_lines = function(text)
  local lines = {}

  for line in string.gmatch(text, "[^\n]+") do
    table.insert(lines, line)
  end

  return lines
end

M.redraw_buff = function(bufnr, win, run)
  if not vim.api.nvim_win_is_valid(win) then return end

  vim.api.nvim_win_set_option(win, "winbar", M.win_title .. " - " .. M.win_title_state)
  if M.error_data ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, split_lines(M.error_data))
  elseif run then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    for line_index, notification in ipairs(run.notifications) do
      line_index = line_index - 2
      if notification.type ~= "start" then
        vim.api.nvim_buf_set_lines(bufnr, line_index, line_index, false, {notification:to_s()})
        vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(bufnr), 0})
        vim.api.nvim_buf_set_extmark(bufnr, M.highlight_ns_id, line_index, 0, {
          hl_group = M.highlight_type_for(notification.type),
          end_col = #notification:to_s(),
        })
      end
    end

    if run.spec_count > 0 then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "Ran using: " .. M.spec_runs[1].cmd .. " " .. table.concat(M.spec_runs[1].cmd_args, " ") })
    end
  end
end

M.highlight_type_for = function(type)
  if type == "example_passed" then
    return "NSpectGreen"
  elseif type == "example_failed" then
    return "NSpectRed"
  else
    return "NSpectYellow"
  end
end

M.open_prev_run = function ()
  local bufnr, win = M.create_run_buf()
  M.redraw_buff(bufnr, win, M.spec_runs[1])
end

M.close_win = function()
  for _, win in ipairs(M.wins) do
    if(vim.api.nvim_win_is_valid(win)) then
      vim.api.nvim_win_close(win, false)
    end
  end
  M.wins = {}
end

M.copy_command_to_clipboard = function()
  local prev_run = M.spec_runs[1]
  local cmd_str = prev_run.cmd

  for _, cmd in ipairs(prev_run.cmd_args) do
    if(cmd == "--require") then
      break
    end

    cmd_str = cmd_str .. " " .. cmd
  end

  vim.fn.setreg("+", cmd_str)
  vim.notify("Spec command copied to clipboard")
end

M.create_run_buf = function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":lua require('nspect').close_win()<CR>", { silent=true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", ":lua require('nspect').run_highlighted_spec()<CR>", { silent=true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "y", ":lua require('nspect').copy_command_to_clipboard()<CR>", { silent=true })

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0,
    col = math.floor(vim.o.columns / 2),
    width = math.floor(vim.o.columns / 2),
    height = vim.o.lines - 3,
    style = "minimal",
    border = "rounded",
  })

  table.insert(M.wins, win)
  return bufnr, win
end

return M
