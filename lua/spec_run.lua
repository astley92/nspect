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

function SpecRun:ingest_notification(notification)
  if notification.type == "start" then
    self.spec_count = notification.spec_count
    self.start_notification = notification
  else
    table.insert(self.notifications, notification)
  end
end

return SpecRun
