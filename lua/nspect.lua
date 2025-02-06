---@diagnostic disable: undefined-global

local RSpecParser = require("rspec_parser")

local M = {}

M.setup = function()
  M.plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*)/lua(.*)$")
  M.notifications = {}
  M.run_data = nil

  vim.keymap.set("n", "<leader>R", M.reload_plugin)
  vim.keymap.set("n", "<leader>F", M.run_file)
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

M.run_file = function()
  M.notifications = {}
  local filepath = vim.api.nvim_buf_get_name(0)

  if not filepath:match(".*_spec%.rb") then
    print("NOT in a spec file")
    return
  end

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
    title = "NSpect",
  })

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

  M.run_data = cmd .. " " .. table.concat(cmd_args, " ") .. "\n \n"
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  vim.uv.spawn(cmd, {
    args = cmd_args,
    stdio = { nil, stdout, stderr }
  }, function()
    print("finished")
  end)

  vim.uv.read_start(stdout, function(_err, data)
    if not data then return end

    M.run_data = M.run_data .. data
    vim.schedule(function()
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        table.insert(M.notifications, notification)
      end
      M.redraw_buff(bufnr, win)
    end)
  end)

  vim.uv.read_start(stderr, function(_err, data)
    if not data then return end

    M.run_data = M.run_data .. data
    vim.schedule(function()
      RSpecParser.parse(data)
      local notifications = RSpecParser.parse(data)
      for _, notification in ipairs(notifications) do
        table.insert(M.notifications, notification)
      end
      M.redraw_buff(bufnr, win)
    end)
  end)
end

M.redraw_buff = function(bufnr, win)
  local line_index = 1

  vim.print(M.notifications)
  for _, notification in ipairs(M.notifications) do
    if notification.type ~= "start" then
      vim.api.nvim_buf_set_lines(bufnr, line_index, line_index, false, {notification:to_s()})
      vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(bufnr), 0})
      line_index = line_index + 1
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {notification:to_s()})
      vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(bufnr), 0})
    end
  end
end

M.open_prev_run = function ()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q<CR>", { silent=true })

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0,
    col = math.floor(vim.o.columns / 2),
    width = math.floor(vim.o.columns / 2),
    height = vim.o.lines - 3,
    style = "minimal",
    border = "rounded",
    title = "NSpect",
  })

  M.redraw_buff(bufnr, win)
end

return M
