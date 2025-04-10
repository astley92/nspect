local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager:new()
  local self = setmetatable({}, WindowManager)

  self.results_window = nil
  self.output_window = nil
  self.results_buf = nil
  self.output_buf = nil

  return self
end

function WindowManager:close_all_windows()
  if (self.results_window ~= nil) then
    if(vim.api.nvim_win_is_valid(self.results_window)) then
      vim.api.nvim_win_close(self.results_window, false)
    end
    self.results_window = nil
    self.results_buf = nil
  end

  if (self.output_window ~= nil) then
    if(vim.api.nvim_win_is_valid(self.output_window)) then
      vim.api.nvim_win_close(self.output_window, false)
    end
    self.output_window = nil
    self.output_buf = nil
  end
end

function WindowManager:open_all_windows()
  local output_window, output_buf = WindowManager.create_window(
    vim.o.columns / 2,
    math.floor((vim.o.lines - 3) / 2) + 2,
    math.floor(vim.o.columns / 2),
    math.floor((vim.o.lines - 3) / 2) - 2
  )
  local results_win, results_buf = WindowManager.create_window(
    vim.o.columns / 2,
    0,
    math.floor(vim.o.columns / 2),
    math.floor((vim.o.lines - 3) / 2)
  )

  self.results_window = results_win
  self.output_window = output_window
  self.results_buf = results_buf
  self.output_buf = output_buf

  return results_buf, output_buf
end

function WindowManager.create_window(x, y, width, height)
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

return WindowManager
