#!/usr/bin/env lua5.1

local seawolf = require [[seawolf]].__build([[text]], [[contrib]])
local trim, xtable = seawolf.text.trim, seawolf.contrib.seawolf_table
local explode, sleep = seawolf.text.explode, require [[socket]].sleep

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

local pids = {}
while true do
  -- Get list of processes
  local plist = os.capture [[ps axo pid,cmd]] or [[]]

  -- Filter processes by pattern
  local commands = xtable()
  for line in plist:gmatch '[^\r\n]+' do
    line = trim(line)
    local pid, cmd = unpack(explode([[ ]], line) or {})

    if pid then
      if 0 < (cmd:find(pattern) or 0) then
        if pids[pid] then
          -- do nothing!
        else
          os.execute(([[cpulimit -b -z -l %s -p %s]]):format(limit, pid))
          pids[pid] = true
        end
      else
        pids[pid] = nil
      end
    end
  end
  sleep(1)
end
