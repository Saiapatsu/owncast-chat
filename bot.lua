
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

-- Try all vararg rate limits, bump all if all pass, none if not
function lims(check, ...)
	local bump = check()
	if not bump then return false end
	if ... and not lims(...) then return end
	bump()
	return true
end
-- To be able to know which one of the limits failed, it should be:
-- Try all vararg rate limits, return failing check, else bump all and nil

-- Call function if lReply and another rate limit pass
local lReply = limiter(5, 15) -- Replying
function ls1call(check, fn, ...)
	if lims(check, lReply) then
		return true, fn(...)
	end
	return false
end

--------------------------------------------------------------------------------

ecCmd = {} -- string -> fn
-- ecList = {} -- Array of ecMap keys
-- ecMap = {} -- Echo command string -> response
-- ecTime = {} -- Ec -> os.time() it was set at
-- ecFd = nil -- Read+append echoes.txt fd number

local function ecCanSet(k)
	local previous = ecCmd[k]
	return previous == cmdRecall or previous == nil
end

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
		-- return print(string.format("ecLine error at pos %d", pos))
		-- I've begun dumping manual echoes here, anything that's not json can just be ignored
		return
	end
	
	local k, v, t = x.k, x.v, x.t
	if not k and t then
		return print(string.format("ecLine incomplete at pos %d", pos))
	end
	
	if type(t) == "string" then
		t = assert(parseTimestamp(t))
	end
	
	if not ecCanSet(k) then
		return
	elseif v then
		ecMap[k] = v
		ecTime[k] = t
		ecCmd[k] = cmdRecall
	else
		ecMap[k] = nil
		ecTime[k] = nil
		ecCmd[k] = nil
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
		return (ecTime[a] or 0) > (ecTime[b] or 0)
	end)
	
	print(string.format("Loaded %d echoes", #ecList))
end

local function ecAppend(k, v, t, m)
	if not ecFd then return end
	fs.writeSync(ecFd, nil, json.stringify({k = k, v = v, t = t, m = m}) .. "\n")
	fs.fsyncSync(ecFd)
end

function ecSet(k, v, t, m)
	if type(t) == "string" then
		t = assert(parseTimestamp(t))
	end
	
	if v then
		if not ecMap[k] then
			table.insert(ecList, k)
		end
		ecAppend(k, v, t, m)
		ecMap[k] = v
		ecTime[k] = t
		ecCmd[k] = cmdRecall
	else
		if not ecMap[k] then return end
		ecAppend(k, v, t, m)
		ecMap[k] = nil
		ecTime[k] = nil
		ecCmd[k] = nil
		for i,v in ipairs(ecList) do
			if v == k then
				table.remove(ecList, i)
				return
			end
		end
	end
end

--------------------------------------------------------------------------------

REP_MAX_LEN = 32

local function repOpen()
	if repFd then
		p("Closing repFd:", fs.closeSync(repFd))
	end
	
	repMap = {}
	
	local function opened(...)
		if ... then
			repFd = ...
		else
			p("Failed to open repFd:", ...)
		end
	end
	
	opened(fs.openSync("data/rep.txt", "a+"))
end

local function repLine(pos, str)
	local x = json.parse(str)
	
	if type(x) ~= "table" then
		return print(string.format("repLine error at pos %d", pos))
	end
	
	local k, v, d = x.k, x.v, x.d
	
	if not k then
		return print(string.format("repLine incomplete at pos %d", pos))
	elseif v then
		repMap[k] = v
	elseif d then
		repMap[k] = (repMap[k] or 0) + d
	else
		return print(string.format("repLine incomplete at pos %d", pos))
	end
end

function repLoad()
	repOpen()
	if not repFd then return end
	
	local str = fs.readSync(repFd, fs.fstatSync(repFd).size)
	for pos, line in str:gmatch("()([^\r\n]+)") do
		xpcall(repLine, print, pos, line)
	end
	
	print("Loaded karma")
end

function repAppend(k, v, d)
	if not repFd then return end
	fs.writeSync(repFd, nil, json.stringify({k = k, v = v, d = d}) .. "\n")
	fs.fsyncSync(repFd)
end

function repMod(str, delta)
	local value = (repMap[str] or 0) + delta
	repAppend(str, value, delta)
	repMap[str] = value
	return value
end

--------------------------------------------------------------------------------

local function reltime(dt)
	-- DANGER! %.f rounds instead of truncating: string.format("%.1f", 3599/3600)
	-- But this is only a problem in Lua 5.3 where you can't %d floats
	if (dt >= 518400) then return string.format("%dd", math.floor(dt/86400)) end -- 6d
	if (dt >=  86400) then return string.format("%dd%dh", math.floor(dt/86400), math.floor(dt % 86400 / 3600)) end -- 1d0h..5d23h
	if (dt >=   3600) then return string.format("%.1fh", math.floor(dt/360)/10) end -- 1.0h..23.9h
	if (dt >=   60) then return string.format("%dmin", math.floor(dt/60)) end -- 1min .. 59min
	return string.format("%dsec", math.floor(dt)) -- 0sec..59sec
end -- snippet 99FC610C994C1235081EB788912EDBAF 20260301181419

--------------------------------------------------------------------------------

lAll = limiter(20, 30) -- Rate limit for running any known command
local lEcho = limiter(2, 6)
local lRecall = limiter(2, 4)
local lRep = limiter(5, 15)
local lHelpMain = limiter(1, 8)
local lHelpSub = limiter(3, 8)

-- Do nothing, but prevent overwriting with an echo
function cmdNothing(act)
end

function cmdEcho(act, reply, cmd, rest, msg, neat)
	if not lims(lAll) then return end
	
	if act == "help" then
		local echoes = ecList[1]
			and ("Echoes: !" .. table.concat(ecList, ", !") .. ".")
			or "No echoes available."
		return ls1call(lHelpSub, reply, string.format("`Use !echo <cmd> <text> to add or modify a command, !echo <cmd> to clear, !<cmd> <text> to modify.\n%s`", echoes))
	elseif act ~= "cmd" then
		return
	end
	
	local name, rest = neat:match("^!?([^ \t\r\n]+)[ \t\r\n]*()", rest)
	if not name then
		return cmdEcho("help", reply)
	end
	
	if not ecCanSet(name) then
		return ls1call(lEcho, reply, "`That's already a command.`")
	end
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	local t = msg.timestamp or os.time()
	
	if new then
		local what = ecMap[name] and "Updated" or "Added"
		ecSet(name, new, t, msg and msg.id)
		ls1call(lEcho, reply, string.format("`%s echo !%s.`", what, name))
	else
		if ecMap[name] then
			ecSet(name, nil, t, msg and msg.id)
			ls1call(lEcho, reply, string.format("`Cleared echo !%s.`", name))
		else
			ls1call(lEcho, reply, "`Nothing happens.`")
		end
	end
end

function cmdRecall(act, reply, cmd, rest, msg, neat)
	if not lims(lAll) then return end
	
	if act == "help" then
		return ls1call(lHelpSub, reply, string.format("`!%s is an echo command.`", cmd))
	elseif act ~= "cmd" then
		return
	end
	
	local str = ecMap[cmd]
	if not str then return end
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	local t = msg.timestamp or os.time()
	
	if new then
		ecSet(cmd, new, t, msg and msg.id)
		ls1call(lRecall, reply, string.format("`Updated echo !%s.`", cmd))
	else
		local t = ecTime[cmd]
		local ago = t and reltime(os.time() - t) or "?"
		
		ls1call(lRecall, reply, string.format("`%s [%s]`", str, ago))
	end
end

function cmdHelp(act, reply, cmd, rest, msg, neat)
	if not lims(lAll) then return end
	
	if act == "help" then
		return ls1call(lHelpSub, reply, "`You know it, buddy.`")
	elseif act ~= "cmd" then
		return
	end
	
	local name, rest = neat:match("^!?([^ \t\r\n]+)[ \t\r\n]*()", rest)
	
	if not name then
		local echoes = ecList[1]
			and (" !" .. table.concat(ecList, " !"))
			or ""
		
		return ls1call(lHelpMain, reply, string.format("`.!help !echo !++ !--%s`", echoes))
	end
	
	local fn = ecCmd[name]
	if fn then
		fn("help", reply, name, rest, msg, neat)
	end
end

function repCmd(delta, act, reply, cmd, rest, msg, neat)
	if not lims(lAll) then return end
	
	if act == "help" then
		local a = delta == 1 and "Add" or "Remove"
		local b = delta == 1 and "to" or "from"
		local c = delta == 1 and "++" or "--"
		return ls1call(lHelpSub, reply, string.format("`%s one point of karma %s something, case-sensitive. Usage: !%s foo, foo%s`", a, b, c, c))
	elseif act ~= "cmd" then
		return
	end
	
	local str = neat:sub(rest)
	if #str > REP_MAX_LEN then
		return ls1call(lRep, reply, "`Be more concise, please.`")
	end
	
	local value = repMod(str, delta)
	if value then
		return ls1call(lRep, reply, string.format("`'%s' now has %d karma.`", str, value))
	end
end

function cmdRepAdd(...)
	repCmd(1, ...)
end

function cmdRepRem(...)
	repCmd(-1, ...)
end

--------------------------------------------------------------------------------

function lsay(str)
	print("< " .. str)
end

function onChat(neat, msg, reply)
	if not tailing then return end
	
	msg = msg or {}
	reply = reply or lsay
	
	if noclanking and noclanking(neat, msg, reply) then
		return
	end
	
	local cmd, rest = neat:match("^!([^ \t\r\n]+)[ \t\r\n]*()")
	if cmd then
		local fn = ecCmd[cmd]
		if fn then
			fn("cmd", reply, cmd, rest, msg, neat)
		end
		return
	end
	
	if #neat <= REP_MAX_LEN then
		local last2 = neat:sub(-2)
		if last2 == "++" or last2 == "--" then
			local fn = ecCmd[last2]
			if fn then
				local cut = neat:sub(1, -3)
				fn("cmd", reply, last2, 1, msg, cut)
				return
			end
		end
	end
end

ecCmd.help = cmdHelp
ecCmd.echo = cmdEcho
ecCmd["++"] = cmdRepAdd
ecCmd["--"] = cmdRepRem

ecLoad()
repLoad()
