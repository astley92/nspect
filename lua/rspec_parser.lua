local RSpecParser = {}

local StartNotification = {}
StartNotification.__index = StartNotification

function StartNotification:new(args)
  self.type = "start"
  self.spec_count = args.example_count

  return self
end

local ExampleNotification = {}
ExampleNotification.__index = ExampleNotification

function ExampleNotification:new(args)
  self.type = args.type
  self.small_filepath = args.small_filepath
  self.line_number = args.line_number

  return self
end

function ExampleNotification:to_s()
  local state
  if self.type == "example_passed" then
    state = "Pass"
  elseif self.type == "example_pending" then
    state = "Pending"
  else
    state = "Fail"
  end
  return self.small_filepath .. ":" .. self.line_number .. " - " .. state
end

LastTail = ""
function RSpecParser.parse(text)
  local lines = {}
  local line = ""
  local is_open = false
  local open_count = 0
  local indicator = '"sender":"nspect"'

  text = LastTail..text
  for i = 1, #text do
    local char = text:sub(i, i)

    if is_open then
      line = line .. char
    end

    if char == "{" and string.sub(text, i+1, i+#indicator) == indicator and not is_open then
      is_open = true
      line = "{"
      open_count = 1
    elseif char == "{" and is_open then
      open_count = open_count + 1
    elseif char == "}" and is_open and open_count == 1 then
      table.insert(lines, line)
      open_count = 0
      is_open = false
      line = ""
    elseif char == "}" and is_open then
      open_count = open_count - 1
    end
  end

  LastTail = line

  local results = {}

  for _, line in ipairs(lines) do
    local args = vim.json.decode(line)
    local noti
    if args.type == "start" then
      noti = StartNotification:new(args)
    else
      noti = ExampleNotification:new(args)
    end
    table.insert(results, noti)
  end

  return results
end

return RSpecParser
