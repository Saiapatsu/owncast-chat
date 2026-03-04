
onChat = nil

--------------------------------------------------------------------------------

-- local i = 0

function limiter(count, period)
	local dt = period/count
	local t = 0
	-- i = i + 1
	-- local i = i
	
	local function bump()
		-- print("bump " .. i)
		t = math.max(os.time(), t) + dt
	end
	
	local function check()
		-- false if rate limited and should quit
		-- print(string.format("check %d %.2f", i, (period - (math.max(os.time(), t) - os.time())) / dt))
		return os.time() + period - dt >= t and bump
	end
	
	return check, bump
end

local   lAll = limiter(20, 30) -- Rate limit for running any known command
local   lSay = limiter(5, 15) -- Replying
local lEcSet = limiter(2, 6) -- Replying to !echo itself
local lEcGet = limiter(2, 4) -- Replying to echos
local lHelpGet = limiter(1, 8) -- Replying to !help

-- Try all vararg rate limits, bump all if all pass, none if not
local function lims(check, ...)
	local bump = check()
	if not bump then return false end
	if ... and not lims(...) then return end
	bump()
	return true
end
-- To be able to know which one of the limits failed, it should be:
-- Try all vararg rate limits, return failing check, else bump all and nil

-- Call function if lSay and another rate limit pass
local function ls1call(check, fn, ...)
	if lims(check, lSay) then
		return true, fn(...)
	end
	return false
end

--------------------------------------------------------------------------------

-- ecList = {} -- Array of ecMap keys
-- ecMap = {} -- Echo command string -> response
-- ecTime = {} -- Ec -> os.time() it was set at
-- ecFd = nil -- Read+append echoes.txt fd number

-- Bot commands that shouldn't be echoable
ecReserved = {
	echo = true,
	help = true,
}

local function ecOpen()
	if ecFd then
		p("Closing ecFd:", fs.closeSync(ecFd))
	end
	
	local function opened(...)
		if ... then
			ecFd = ...
		else
			p("Failed to open ecFd:", ...)
		end
	end
	
	opened(fs.openSync("data/echoes.txt", "a+"))
end

local function ecLine(pos, str)
	local x = json.parse(str)
	
	if type(x) ~= "table" then
		return print(string.format("ecLine error at pos %d", pos))
	end
	
	local k, v, t = x.k, x.v, x.t
	if not k and t then
		return print(string.format("ecLine incomplete at pos %d", pos))
	end
	
	if v then
		ecMap[k] = v
		ecTime[k] = t
	else
		ecMap[k] = nil
		ecTime[k] = nil
	end
end

function ecLoad()
	ecOpen()
	if not ecFd then return end
	
	ecList = {}
	ecMap = {}
	ecTime = {}
	
	local str = fs.readSync(ecFd, fs.fstatSync(ecFd).size)
	for pos, line in str:gmatch("()([^\r\n]+)") do
		xpcall(ecLine, print, pos, line)
	end
	
	for k in pairs(ecMap) do
		table.insert(ecList, k)
	end
	
	table.sort(ecList, function(a, b)
		return (ecTime[a] or 0) < (ecTime[b] or 0)
	end)
	
	print(string.format("Loaded %d echoes", #ecList))
end

local function ecAppend(k, v, t, m)
	if not ecFd then return end
	fs.writeSync(ecFd, nil, json.stringify({k = k, v = v, t = t, m = m}) .. "\n")
	fs.fsyncSync(ecFd)
end

function ecSet(k, v, m)
	if v then
		if not ecMap[k] then
			table.insert(ecList, k)
		end
		local t = os.time()
		ecAppend(k, v, t, m)
		ecMap[k] = v
		ecTime[k] = t
	else
		if not ecMap[k] then return end
		local t = os.time()
		ecAppend(k, v, t, m)
		ecMap[k] = nil
		ecTime[k] = nil
		for i,v in ipairs(ecList) do
			if v == k then
				table.remove(ecList, i)
				return
			end
		end
	end
end

ecLoad()

--------------------------------------------------------------------------------

local function reltime(dt)
	-- DANGER! %.f rounds instead of truncating: string.format("%.1f", 3599/3600)
	-- But this is only a problem in Lua 5.3 where you can't %d floats
	if (dt >= 518400) then return string.format("%dd", math.floor(dt/86400)) end -- 6d
	if (dt >=  86400) then return string.format("%dd%dh", math.floor(dt/86400), math.floor(dt % 86400 / 3600)) end -- 1d0h..5d23h
	if (dt >=   3600) then return string.format("%.1fh", math.floor(dt/360)/10) end -- 1.0h..23.9h
	return string.format("%02d:%02d", math.floor(dt/60), math.floor(dt%60)) -- 00:00..59:59
end -- snippet 99FC610C994C1235081EB788912EDBAF 20260301181419

local function cmdEcho(neat, msg, reply, cmd, rest)
	if cmd ~= "echo" then return true end
	
	if not lims(lAll) then return end
	
	local name, rest = neat:match("^!?([^ \t\r\n]+)[ \t\r\n]*()", rest)
	
	if not name then
		if ecList[1] then
			ls1call(lEcSet, reply, string.format("`Echoes: !%s. Use !echo <cmd> <text> or !<cmd> <text> to add or modify an echo command.`", table.concat(ecList, ", !")))
		else
			ls1call(lEcSet, reply, string.format("`No echoes available.`"))
		end
		return
	elseif ecReserved[name] then
		ls1call(lEcSet, reply, "`That's already a command.`")
		return
	end
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	if new then
		local what = ecMap[name] and "Updated" or "Added"
		ecSet(name, new, msg and msg.id)
		ls1call(lEcSet, reply, string.format("`%s echo !%s.`", what, name))
	else
		if ecMap[name] then
			ecSet(name, nil, msg and msg.id)
			ls1call(lEcSet, reply, string.format("`Cleared echo !%s.`", name))
		else
			ls1call(lEcSet, reply, "`Nothing happens.`")
		end
	end
end

local function cmdRecall(neat, msg, reply, cmd, rest)
	local name = cmd
	
	local str = ecMap[name]
	if not str then return true end
	
	if not lims(lAll) then return end
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	if new then
		local what = ecMap[name] and "Updated" or "Added"
		ecSet(name, new, msg and msg.id)
		ls1call(lEcGet, reply, string.format("`%s echo !%s.`", what, name))
	else
		local t = ecTime[name]
		local ago = t and reltime(os.time() - t) or "?"
		
		ls1call(lEcGet, reply, string.format("`%s [%s]`", str, ago))
	end
end

local function cmdHelp(neat, msg, reply, cmd, rest)
	if cmd ~= "help" then return true end
	
	local list = ecList[1]
		and string.format("Echoes: !%s.", table.concat(ecList, ", !"))
		or "No echoes configured."
	
	ls1call(lHelpGet, reply, string.format("`My commands: !help, !echo. %s`", list))
end

--------------------------------------------------------------------------------

function lsay(str)
	print("< " .. str)
end

function onChat(neat, msg, reply)
	if not tailing then return end
	
	local cmd, rest = neat:match("^!([^ \t\r\n]+)[ \t\r\n]*()")
	if not cmd then return end
	
	msg = msg or {}
	reply = reply or lsay
	
	-- truthy to fall through, falsy to handle
	return cmdHelp(neat, msg, reply, cmd, rest)
	and cmdEcho(neat, msg, reply, cmd, rest)
	and not ecReserved[cmd]
	and cmdRecall(neat, msg, reply, cmd, rest)
end
