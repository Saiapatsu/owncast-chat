
onChat = nil

-- Other bots' commands
botReserved = {}

--------------------------------------------------------------------------------

function limiter(count, period)
	local dt = period/count
	local t = 0
	
	return function()
		-- true if rate limited and should quit
		return os.clock() + period - dt < t
	end, function()
		t = math.max(os.clock(), t) + dt
	end
end

local   lAll,   bAll = limiter(5, 20)
local lEcSet, bEcSet = limiter(2, 6)
local lEcUse, bEcUse = limiter(2, 4)

--------------------------------------------------------------------------------

-- ecList = {} -- Array of ecMap keys
-- ecMap = {} -- Echo command string -> response
-- ecTime = {} -- Ec -> os.time() it was set at
-- ecFd = nil -- Read+append echoes.txt fd number

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
	if (dt >= 172800) then return string.format("%dd", dt / 86400) end -- 2d
	if (dt >=   1800) then return string.format("%.1fh", dt / 3600) end -- 0.5h - 47.9h
	if (dt >=    300) then return string.format("%dmin", dt / 60) end -- 5min - 29min
	if (dt >=     60) then return string.format("%.1fmin", dt / 60) end -- 1.0min - 4.9min
	return string.format("%dsec", dt)
end -- snippet 99FC610C994C1235081EB788912EDBAF 20260301181419

local function cmdEcho(cmd, rest, neat, msg, reply)
	if lAll() then return end
	if lEcSet() then return end
	bAll()
	bEcSet()
	
	local name, rest = neat:match("^!?([^ \t\r\n]+)[ \t\r\n]*()", rest)
	
	if not name then
		if ecList[1] then
			reply("\\* Echoes: " .. table.concat(ecList, ", ") .. ".")
		else
			reply("\\* No echoes available.")
		end
		return
	elseif botReserved[name] then
		reply("\\* That's disrespectful to the other bots.")
		return
	end
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	if new then
		local what = ecMap[name] and "Updated" or "Added"
		ecSet(name, new, msg and msg.id)
		reply(string.format("\\* %s echo !%s.", what, name))
	else
		if ecMap[name] then
			ecSet(name, nil, msg and msg.id)
			reply(string.format("\\* Cleared echo !%s.", name))
		else
			reply("\\* Nothing happens.")
		end
	end
end

local function cmdRecall(cmd, rest, neat, msg, reply)
	local name = cmd
	
	local str = ecMap[name]
	if not str then return end
	
	if lAll() then return end
	if lEcUse() then return end
	bAll()
	bEcUse()
	
	local new = neat:match("[^\t\r\n]+", rest)
	
	if new then
		local what = ecMap[name] and "Updated" or "Added"
		ecSet(name, new, msg and msg.id)
		reply(string.format("\\* %s echo !%s.", what, name))
	else
		local t = ecTime[name]
		local ago = t and reltime(os.time() - t) or "?"
		
		reply(string.format("\\* %s [%s]", str, ago))
	end
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
	
	if cmd == "echo" then
		return cmdEcho(cmd, rest, neat, msg, reply)
		
	elseif botReserved[cmd] then
		-- Nothing
		
	else
		return cmdRecall(cmd, rest, neat, msg, reply)
	end
end
