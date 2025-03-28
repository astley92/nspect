local SpecRun = {}
SpecRun.__index = SpecRun

function SpecRun:new(cmd, cmd_args)
  local self = setmetatable({}, SpecRun)

  self.cmd = cmd
  self.cmd_args = cmd_args
  self.spec_count = 0
  self.start_notification = {}
  self.notifications = {}
  self.state = "Idle"

  return self
end

return SpecRun
