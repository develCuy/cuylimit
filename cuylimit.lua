#!/usr/bin/env lua5.1

local seawolf = require [[seawolf]].__build([[text]], [[contrib]], [[variable]])
local trim, xtable = seawolf.text.trim, seawolf.contrib.seawolf_table
local explode, sleep = seawolf.text.explode, require [[socket]].sleep
local is_numeric = seawolf.variable.is_numeric

local pattern = arg[1]
local limit = arg[2]

if nil == pattern or nil == limit then
  print "Usage: cuylimit pattern limit\n"
  print "  pattern   i.e: chrome"
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

-- Avoid running multiple instances with same params
do
  local mycmd = ('%s %s %s'):format(arg[-1], arg[0], table.concat(arg, ' '))
  local count = 0
  for line in ((os.capture('pgrep -a -f "' .. mycmd .. '"')):gmatch '[^\r\n]+') do
    local pid, cmd = line:gmatch [[(%d+) (.+)]] ()
    if cmd == mycmd then
      count = count + 1
    end
    if count > 1 then
      io.stderr:write "There is already another cuylimit instance running with same parameters. Exiting...\n"
      os.exit(0)
    end
  end
end

-- Detect user invoking this script
local uid = ((os.capture 'id -u'):gmatch '[^\r\n]+')()
if not is_numeric(uid) then
  io.stderr:write "ERROR: Can't detect real user ID (UID)\n"
  os.exit(1)
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
      local limited_pid = cmd:gmatch([[cuylimit_(%d+)]])()

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
        local limitcmd = ('cpulimit -q -b -z -l %s -p %s'):format(pid, limit)
        os.execute(('bash -c "exec -a cuylimit_%s %s"'):format(pid, limitcmd))
      end
    end
  end

  sleep(1)
end
