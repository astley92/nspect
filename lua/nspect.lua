---@diagnostic disable: undefined-global

local RSpecParser = require("rspec_parser")
local SpecRun = require("spec_run")

local M = {}

M.setup = function(config)
  if config == nil then config = {} end

  M.config = config
  M.plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*)/lua(.*)$")
  M.spec_runs = {}
  M.title = "NSpect 🧪"
  M.results_window = nil
  M.output_window = nil
  M.highlight_ns_id = vim.api.nvim_create_namespace("NSpectHighlight")
  M.results_cursor_pos = 1
  M.augroup = vim.api.nvim_create_augroup("NSpectAugroup", {clear = true})

  vim.keymap.set("n", config.reload_nspect_keymap or "<leader>R", M.reload_plugin)
  vim.keymap.set("n", config.run_file_keymap or "<leader>F", M.run_file)
  vim.keymap.set("n", config.run_line_keymap or "<leader>H", M.run_line)
  vim.keymap.set("n", config.run_previous_keymap or "<leader>G", M.run_previous)
  vim.keymap.set("n", config.open_prev_keymap or "<leader>O", M.open_prev_run)

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
  package.loaded["spec_run"] = nil
  RSpecParser = require("rspec_parser")
  SpecRun = require("spec_run")

  local plug = require("nspect")
  plug.setup()
  vim.notify("Reloading NSpect")
end

M.run_file = function()
  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local cmd, cmd_args = M.build_command("file", filepath, nil)

  table.insert(M.spec_runs, 1, SpecRun:new(cmd, cmd_args))
  if #M.spec_runs > 10 then table.remove(M.spec_runs) end
  M.execute_run(1)
end

M.run_line = function()
  local filepath = vim.api.nvim_buf_get_name(0)
  if not filepath:match(".*_spec%.rb") then
    return
  end
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local cmd, cmd_args = M.build_command("line", filepath, line_number)

  table.insert(M.spec_runs, 1, SpecRun:new(cmd, cmd_args))
  if #M.spec_runs > 10 then table.remove(M.spec_runs) end
  M.execute_run(1)
end

M.run_previous = function()
  if #M.spec_runs < 1 then return end

  local prev_run = M.spec_runs[1]

  table.insert(M.spec_runs, 1, SpecRun:new(prev_run.cmd, prev_run.cmd_args))
  if #M.spec_runs > 10 then table.remove(M.spec_runs) end
  M.execute_run(1)
end

M.run_highlighted_spec = function()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local spec = M.spec_runs[1].notifications[cursor_line]

  if(spec == nil) then
    return
  end

  local cmd, cmd_args = M.build_command("line", spec.full_filepath, spec.line_number)
  table.insert(M.spec_runs, 1, SpecRun:new(cmd, cmd_args))
  if #M.spec_runs > 10 then table.remove(M.spec_runs) end
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
    "--require",
    M.plugin_root .. "/rspec_formatter/jsonl_formatter.rb",
    "--format",
    "NSpect::JSONLFormatter",
    "--no-color"
  }

  if type == "multiple" then
    for _, path in ipairs(filepath) do
      table.insert(cmd_args, 1, path)
    end
  else
    table.insert(cmd_args, 1, command_file_part)
  end

  if use_bundle then
    cmd = "bundle"
    table.insert(cmd_args, 1, "rspec")
    table.insert(cmd_args, 1, "exec")
  else
    cmd = "rspec"
  end

  return cmd, cmd_args
end

M.create_run_windows = function(run)
  local output_window, output_buf = M.create_window(vim.o.columns / 2, math.floor((vim.o.lines - 3) / 2) + 2, math.floor(vim.o.columns / 2), math.floor((vim.o.lines - 3) / 2) - 2)
  local results_win, results_buf = M.create_window(vim.o.columns / 2, 0, math.floor(vim.o.columns / 2), math.floor((vim.o.lines - 3) / 2))

  vim.api.nvim_buf_set_keymap(results_buf, "n", M.config.close_windows_keymap or "q", ":lua require('nspect').close_windows()<CR>", { silent=true })
  vim.api.nvim_buf_set_keymap(results_buf, "n", M.config.run_highlighted_spec_keymap or  "<CR>", ":lua require('nspect').run_highlighted_spec()<CR>", { silent=true })
  vim.api.nvim_buf_set_keymap(results_buf, "n", M.config.copy_command_keymap or "y", ":lua require('nspect').copy_command_to_clipboard()<CR>", { silent=true })
  vim.api.nvim_buf_set_keymap(results_buf, "n", M.config.run_failed_keymap or "f", ":lua require('nspect').run_failed_specs()<CR>", { silent=true })

  vim.api.nvim_buf_set_keymap(output_buf, "n", "q", ":lua require('nspect').close_windows()<CR>", { silent=true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = results_buf,
    group = M.augroup,
    callback = function()
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      if run.notifications[cursor_line] == nil then return end

      M.results_cursor_pos = cursor_line
      M.draw(run)
    end,
  })

  return output_window, results_win
end

M.execute_run = function(run_index)
  local run = M.spec_runs[run_index]

  M.close_windows()
  M.results_cursor_pos = 1
  local output_window, win = M.create_run_windows(run)
  M.results_window = win
  M.output_window = output_window

  local cmd = run.cmd
  local cmd_args = run.cmd_args
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()

  vim.uv.spawn(cmd, {
    args = cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    vim.schedule(function()
      if run.error_data == "" then
        run.state = "Complete"
      else
        run.state = "Failed"
      end
      M.draw(run)
    end)
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        run:ingest_notification(notification)
      end
      M.draw(run)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end

    run.error_data = run.error_data .. data
    vim.schedule(function()
      M.draw(run)
    end)
  end)
end

local split_lines = function(text)
  local lines = {}

  local line = ""
  for i = 1, #text do
    local c = text:sub(i, i)
    if c == "\n" then
      table.insert(lines, line)
      line = ""
    else
      line = line .. c
    end
  end

  table.insert(lines, line)
  return lines
end

M.draw = function(run)
  -- Results window drawing
  local win = M.results_window
  if not vim.api.nvim_win_is_valid(win) then return end

  local bufnr = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_win_set_option(win, "winbar", M.title .. " - " .. run.state)
  if run.error_data ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, split_lines(run.error_data))
    return
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  for line_index, notification in ipairs(run.notifications) do
    line_index = line_index - 1
    vim.api.nvim_buf_set_lines(bufnr, line_index, line_index, false, {notification:to_s()})
    vim.api.nvim_buf_set_extmark(bufnr, M.highlight_ns_id, line_index, 0, {
      hl_group = M.highlight_type_for(notification.type),
      end_col = #notification:to_s(),
    })
  end

  if run.spec_count > 0 then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "Ran using: " .. M.spec_runs[1].cmd .. " " .. table.concat(M.spec_runs[1].cmd_args, " ") })
  end
  vim.api.nvim_win_set_cursor(win, {M.results_cursor_pos, 0})

  -- Output Window Drawing
  win = M.output_window
  bufnr = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  local notification = run.notifications[M.results_cursor_pos]
  if notification == nil then return end

  if notification.stdout ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, split_lines(notification.stdout))
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
  if #M.spec_runs < 1 then return end

  M.close_windows()
  local run = M.spec_runs[1]
  local output_window, win = M.create_run_windows(run)

  M.results_window = win
  M.output_window = output_window

  M.draw(run)
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

M.run_failed_specs = function()
  local file_paths = {}

  for _, notification in ipairs(M.spec_runs[1].notifications) do
    if notification.type == "example_failed" then
      table.insert(file_paths, notification.full_filepath .. ":" .. notification.line_number)
    end
  end

  if #file_paths <= 0 then
    vim.notify("No failures to run")
    return
  end

  local cmd, cmd_args = M.build_command("multiple", file_paths, nil)
  table.insert(M.spec_runs, 1, SpecRun:new(cmd, cmd_args))
  if #M.spec_runs > 10 then table.remove(M.spec_runs) end

  M.execute_run(1)
end

M.close_windows = function()
  if (M.results_window ~= nil) then
    if(vim.api.nvim_win_is_valid(M.results_window)) then
      vim.api.nvim_win_close(M.results_window, false)
    end
    M.results_window = nil
  end

  if (M.output_window ~= nil) then
    if(vim.api.nvim_win_is_valid(M.output_window)) then
      vim.api.nvim_win_close(M.output_window, false)
    end
    M.output_window = nil
  end
end

M.create_window = function(x, y, width, height)
  local bufnr = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = y,
    col = x,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  return win, bufnr
end

return M
