local RSpecParser = {}

local StartNotification = {}
StartNotification.__index = StartNotification

function StartNotification:new(args)
  local self = setmetatable({}, StartNotification)

  self.type = "start"
  self.spec_count = args.example_count

  return self
end

function StartNotification:to_s()
  return "Ran "..self.spec_count.." specs"
end

local ExampleNotification = {}
ExampleNotification.__index = ExampleNotification

function ExampleNotification:new(args)
  local self = setmetatable({}, ExampleNotification)

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

function RSpecParser.parse(text)
  local lines = {}
  local open_count = 0
  local line = ""

  print("doing some parsing")
  for i = 1, #text do
    local char = text:sub(i, i)

    line = line .. char

    if char == "{" then
      open_count = open_count + 1
    elseif char == "}" then
      open_count = open_count - 1
      print("Adding line: " .. line)
      if open_count == 0 then
        table.insert(lines, #lines + 1, line)
        line = ""
      end
    end
  end

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
