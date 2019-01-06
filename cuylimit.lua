#!/usr/bin/env lua5.1

local seawolf = require [[seawolf]].__build([[text]], [[contrib]], [[variable]])
local trim, xtable = seawolf.text.trim, seawolf.contrib.seawolf_table
local explode, sleep = seawolf.text.explode, require [[socket]].sleep
local is_numeric = seawolf.variable.is_numeric

local pattern = arg[1]
local limit = arg[2]

if nil == pattern or nil == limit then
  print "Usage: cuylimit pattern limit\n"
  print "  pattern   The witness username"
  print "  limit     percentage of CPU allowed from 1 up (cpulimit -l)"
  print "\n"
  os.exit(1)
end

function os.capture(cmd)
  local f = assert(io.popen(cmd, [[r]]))
  local s = assert(f:read([[*a]]))
  f:close()
  s = string.gsub(s, '[\n\r]+', '\n')
  return s
end

-- Detect user invoking this script
local uid = ((os.capture 'id -u'):gmatch '[^\r\n]+')()
if not is_numeric(uid) then
  io.stderr:write "ERROR: Can't detect real user ID (UID)\n"
  os.exit()
end

while true do
  local limited = {}
  local procs = {}

  -- Get list of running processes
  for line in (os.capture(('pgrep -a -u %d "(cpulimit|%s)"'):format(uid, pattern)) or ''):gmatch '[^\r\n]+' do
    line = trim(line)
    local pid, cmd = line:gmatch [[(%d+) (.+)]] ()

    if pid then
      -- Filter PIDs controlled by already running instances of cpulimit
      local limited_pid = cmd:gmatch([[cpulimit %-p (%d+) %-]])()

      if limited_pid then
        limited[limited_pid] = true
      else
        procs[pid] = cmd
      end
    end
  end

  -- Find matching processes
  for pid, cmd in pairs(procs) do
    if 0 < (cmd:find(pattern) or 0) and 0 >= (cmd:find [[cuylimit]] or 0) then
      if limited[pid] then
        -- do nothing!
      else
        os.execute(([[cpulimit -p %s -b -z -l %s]]):format(pid, limit))
      end
    end
  end

  sleep(1)
end
