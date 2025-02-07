---@diagnostic disable: undefined-global

local RSpecParser = require("rspec_parser")

local M = {}

M.setup = function()
  M.plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*)/lua(.*)$")
  M.notifications = {}
  M.win_title = "NSpect 🧪"
  M.win_title_state = "Idle"
  M.run_spec_count = nil
  M.previous_command = nil
  M.error_data = ""

  vim.keymap.set("n", "<leader>R", M.reload_plugin)
  vim.keymap.set("n", "<leader>F", M.run_file)
  vim.keymap.set("n", "<leader>H", M.run_line)
  vim.keymap.set("n", "<leader>G", M.run_previous)
  vim.keymap.set("n", "<leader>O", M.open_prev_run)
end

M.reload_plugin = function()
  package.loaded["nspect"] = nil
  package.loaded["rspec_parser"] = nil
  RSpecParser = require("rspec_parser")
  local plug = require("nspect")
  plug.setup()
  print("Reloading NSpect")
end

M.close_win = function()
  vim.api.nvim_win_close(0, false)
end

M.create_run_buf = function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":lua require('nspect').close_win()<CR>", { silent=true })

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0,
    col = math.floor(vim.o.columns / 2),
    width = math.floor(vim.o.columns / 2),
    height = vim.o.lines - 3,
    style = "minimal",
    border = "rounded",
  })

  return bufnr, win
end

M.run_file = function()
  M.notifications = {}
  M.win_title_state = "Starting Up"
  M.run_spec_count = nil
  M.error_data = ""

  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local bufnr, win = M.create_run_buf()
  local use_bundle = vim.fn.filereadable(vim.fn.getcwd().."/".."Gemfile") == 1
  local cmd
  local cmd_args = {
    filepath,
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
  M.previous_command = {
    cmd = cmd,
    cmd_args = cmd_args,
  }

  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  vim.uv.spawn(cmd, {
    args = cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    vim.schedule(function()
      if M.error_data == "" then
        M.win_title_state = "Ran " .. M.run_spec_count .. " specs"
      else
        M.win_title_state = "Failed to run"
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        if notification.type == "start" then
          M.run_spec_count = notification.spec_count
          M.win_title_state = "Running " .. M.run_spec_count .. " specs"
        end
        table.insert(M.notifications, notification)
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end
    M.error_data = M.error_data .. data

    vim.schedule(function()
      M.redraw_buff(bufnr, win)
    end)
  end)
end

M.run_line = function()
  M.notifications = {}
  M.win_title_state = "Starting Up"
  M.run_spec_count = nil
  M.error_data = ""

  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr, win = M.create_run_buf()
  local use_bundle = vim.fn.filereadable(vim.fn.getcwd().."/".."Gemfile") == 1
  local cmd
  local cmd_args = {
    filepath .. ":" .. line_number,
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
  M.previous_command = {
    cmd = cmd,
    cmd_args = cmd_args,
  }
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  vim.uv.spawn(cmd, {
    args = cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    vim.schedule(function()
      if M.error_data == "" then
        M.win_title_state = "Ran " .. M.run_spec_count .. " specs"
      else
        M.win_title_state = "Failed to run"
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        if notification.type == "start" then
          M.run_spec_count = notification.spec_count
          M.win_title_state = "Running " .. M.run_spec_count .. " specs"
        end
        table.insert(M.notifications, notification)
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end
    M.error_data = M.error_data .. data

    vim.schedule(function()
      M.redraw_buff(bufnr, win)
    end)
  end)
end

M.run_previous = function()
  if not M.previous_command then return end

  M.notifications = {}
  M.win_title_state = "Starting Up"
  M.run_spec_count = nil
  M.error_data = ""

  local bufnr, win = M.create_run_buf()

  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  vim.uv.spawn(M.previous_command.cmd, {
    args = M.previous_command.cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    vim.schedule(function()
      if M.error_data == "" then
        M.win_title_state = "Ran " .. M.run_spec_count .. " specs"
      else
        M.win_title_state = "Failed to run"
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        if notification.type == "start" then
          M.run_spec_count = notification.spec_count
          M.win_title_state = "Running " .. M.run_spec_count .. " specs"
        end
        table.insert(M.notifications, notification)
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end
    M.error_data = M.error_data .. data

    vim.schedule(function()
      M.redraw_buff(bufnr, win)
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

M.redraw_buff = function(bufnr, win)
  if not vim.api.nvim_win_is_valid(win) then return end

  vim.api.nvim_win_set_option(win, "winbar", M.win_title .. " - " .. M.win_title_state)
  if M.error_data ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, split_lines(M.error_data))
  else
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local ns_id = vim.api.nvim_create_namespace("NSpectHighlight")
    vim.api.nvim_set_hl(0, "NSpectGreen", {
      fg = "#00F000",
    })
    vim.api.nvim_set_hl(0, "NSpectRed", {
      fg = "#F00000",
    })
    vim.api.nvim_set_hl(0, "NSpectYellow", {
      fg = "#F0F000",
    })

    for line_index, notification in ipairs(M.notifications) do
      line_index = line_index - 2
      if notification.type ~= "start" then
        vim.api.nvim_buf_set_lines(bufnr, line_index, line_index, false, {notification:to_s()})
        vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(bufnr), 0})
        if notification.type == "example_passed" then
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_index, 0, { hl_group = "NSpectGreen", end_col = #notification:to_s() })
        elseif notification.type == "example_failed" then
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_index, 0, { hl_group = "NSpectRed", end_col = #notification:to_s() })
        elseif notification.type == "example_pending" then
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_index, 0, { hl_group = "NSpectYellow", end_col = #notification:to_s() })
        end
      end
    end

    if M.previous_command then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "Ran using: " .. M.previous_command.cmd .. " " .. table.concat(M.previous_command.cmd_args, " ") })
    end
  end
end

M.open_prev_run = function ()
  local bufnr, win = M.create_run_buf()
  M.redraw_buff(bufnr, win)
end

return M
