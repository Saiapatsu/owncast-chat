json = require("json")
fs = require("fs")
timer = require("timer")
uv = require("uv")
utf8 = require("utf8")

local env = getfenv()

function ansim(a, b)
	return string.format("\027[%d;%dm", a, b)
end

local c = {
	--theme-color-users-0: #bc1a32;
	--theme-color-users-1: #b3b3b3;
	--theme-color-users-2: #96c832;
	--theme-color-users-3: #2e8b57;
	--theme-color-users-4: #5f9ea0;
	--theme-color-users-5: #daa520;
	--theme-color-users-6: #847cfe;
	--theme-color-users-7: #ff4500;
	[0] = ansim(22, 31), -- 4 dark red
	[1] = ansim(01, 30), -- 8 dark gray
	[2] = ansim(01, 32), -- a light green
	[3] = ansim(22, 32), -- 2 dark green
	[4] = ansim(22, 36), -- 3 dark aqua
	[5] = ansim(22, 33), -- 6 gold/brown
	[6] = ansim(22, 35), -- 5 dark purple
	[7] = ansim(01, 31), -- c light red
	
	g = ansim(01, 30), -- dark gray, subdued
	w = ansim(01, 37), -- white, highlighted
	x = ansim(01, 31), -- light red, danger
	r = "\027[m", -- reset
	
	-- https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b
	up = "\027[1A", -- "moves cursor up # lines"
}

-- Width in columns of the "gutter" to the left which is to be reserved for
-- usernames and system messages and kept clear of user-submitted messages
gutter = 11
-- Width in columns of the tty
columns = uv.tty_get_winsize(process.stdout.handle)
-- Everything derived from the above
-- chatfmt
-- renamefmt
-- wrapfind
-- spaces
-- spaces1

-- Update expected tty columns
function setColumns(gutter, columns)
	chatfmt = "\r%s%" .. gutter-1 .. "s%s %s%s"
	wrapfind = string.rep(".", columns - gutter)
	spaces = string.rep(" ", gutter)
	spaces1 = "%1" .. spaces
	rule = string.rep("-", columns)
end

setColumns(gutter, columns)

local function xml(str, closing, tag)
	if tag == "p" then
		return ""
	elseif tag == "img" then
		return str:match('alt="([^"]+)')
	elseif tag == "em" then
		return "*"
	elseif tag == "strong" then
		return "**"
	elseif tag == "br" then
		return "\n"
	else
		return #closing == 1
			and ">"
			or "<"
	end
end

local escapes = {
	quot = '"',
	apos = "'",
	amp = "&",
	lt = "<",
	gt = ">",
}

local function entity(str)
	local n = str:match("^#(%d+)$")
	if n then
		return string.char(n)
	end
	
	return escapes[str]
end

local function neaten(str)
	return str
		-- Remove newlines, they are also accompanied by a <br>
		:gsub("\n", "")
		-- Deal with HTML
		:gsub("(<(/?)([^> ]+)[^>]*>)", xml)
		-- Unescape XML entities
		:gsub("&([^; ]+);", entity)
end

-- Line-wrap a string such that it keeps a gutter of spaces to the left
-- after each wrap, UTF-8 aware as long as everything's one cell wide
local function gutterwrap(str, x)
	str = neaten(str)
	
	local rope = {}
	local atRightEdge = false
	local newline = false
	
	-- You can send newlines in chat, wrap within each
	for line in str:gmatch("[^\n]+") do
		if newline then
			table.insert(rope, "\n")
		else
			newline = true
		end
		
		local i = 1
		while true do
			local j = utf8.offset(line, columns-x+1, i)
			atRightEdge = j == #line
			x = gutter
			table.insert(rope, string.sub(line, i, j and j-1))
			if not j or i > #line then break end
			i = j
		end
	end
	
	-- If the last line we're about to send touches the right edge,
	-- send a cursor up command to counter the upcoming \n from print
	return table.concat(rope, spaces) .. (atRightEdge and c.up or "")
end

-- Filled in from config
renames = {}

function loadSetup()
	setfenv(assert(loadfile("./setup.lua")), env)()
end

loadSetup()

local function uanon(user, str)
	str = str or user.displayName
	if str == "Anonymous" then
		return string.format("*%s", user.id)
	end
	return str
end

local function ucolor(user)
	return c[user.displayColor] or c.g
end

function ruleStr(str)
	local half = (columns - #str - 2) / 2
	return string.format("%s %s %s", string.rep("-", math.ceil(half)), str, string.rep("-", math.floor(half)))
end

local lastHour = nil
-- timestamp":"2026-01-19T23:53:58.051312309Z

function line(str)
	local x = json.parse(str)
	
	if type(x) ~= "table" then
		print(string.format("\r%s%s%s%s %s %s|%s%s%s|%s\n%s%s%s%s"
			, c.x, ruleStr("Failed to parse JSON"), c.r
			, type(str), type(x), c.x, c.r, str, c.x, c.r
			, c.x, rule, c.r, c.up
		))
		return
	end
	
	if x.timestamp then
		local hour = x.timestamp:sub(1, 13)
		if hour ~= lastHour then
			lastHour = hour
			local str = x.timestamp:sub(1, 16):gsub("T", " ")
			print(string.format("%s%s%s%s", c.g, ruleStr(str), c.up, c.r))
		end
	end
	
	if x.type == "CHAT" then
		local color = ucolor(x.user)
		local name = renames[x.user.id] or uanon(x.user)
		print(string.format(chatfmt, color, name, c.r, gutterwrap(x.body, math.max(#name + 1, gutter)), c.r))
		
	elseif x.type == "NAME_CHANGE" then
		local color = ucolor(x.user)
		local oldname = uanon(x.user, x.oldName)
		local name = uanon(x.user)
		local ren = renames[x.user.id]
		if ren then
			print(string.format(chatfmt, color, name, c.g, gutterwrap("(" .. ren .. ") renamed from " .. oldname, math.max(#name + 1, gutter)), c.r))
		else
			print(string.format(chatfmt, color, name, c.g, gutterwrap("renamed from " .. oldname, math.max(#name + 1, gutter)), c.r))
		end
		
	elseif x.type == "CHAT_ACTION" then
		print(string.format("\r%s%s%s%s", c.g, ruleStr(neaten(x.body)), c.r, c.up))
		
	elseif x.type == "CONNECTED_USER_INFO" then
		local color = ucolor(x.user)
		local name = uanon(x.user)
		print(string.format("\r%sConnected as %s%s%s", c.g, color, name, c.r))
		
	else
		print(string.format("\r%s<%s> %s%s", c.g, x.type, str, c.r))
	end
end

local function handleError(e)
	print(debug.traceback(e, 2))
	print(line)
end

function line2(str)
	xpcall(line, handleError, str)
end

-- for str in io.lines() do
	-- xpcall(line, handleError, str)
-- end

-- Get filename of last log (wiping off the newline...) and open it
local name = fs.readFileSync("data/wss-last.txt"):match("[^\r\n]+")
local fd = fs.openSync("data/" .. name, "r")

-- Timer handle
local t
-- Half-read line
local half = ""
-- File read position because read(pos) won't affect read()'s own seek point ???
local rpos = 0

local hadData = false

local function onRead(err, str)
	if err then return timer.clearInterval(t) end
	
	if str == "" then
		if hadData then
			refreshLine()
			hadData = false
		end
		return
	else
		if not hadData then
			homeClear()
			hadData = true
		end
	end
	
	rpos = rpos + #str
	
	local pos = str:match("()\n")
	if pos then
		-- New message arrived and there's a newline
		-- Finish the line in progress
		line2(half .. str:sub(1, pos - 1))
		pos = pos + 1
		while true do
			local b = str:match("()\n", pos)
			if b then
				line2(str:sub(pos, b - 1))
				pos = b + 1
			else
				half = str:sub(pos)
				break
			end
		end
	else
		-- New message but no newline, as if longer than the read buffer
		half = half .. str
	end
	
	-- There may be more data
	-- The -1 is because, I shit you not, for some reason it used to skip single
	-- characters and lead to slightly corrupt data or json parse fails sometimes
	fs.read(fd, nil, rpos-1, onRead)
end

local function onReadRecover(err, str)
	if err or str == "" then return end
	local b = str:match("()\n")
	rpos = rpos + b + 1
	return onRead(err, str:sub(b + 1))
end

-- Seek to tail, discard any line it might've jumped into the middle of
function tail()
	rpos = math.max(0, fs.fstatSync(fd).size - 6*4096)
	if rpos == 0 then
		fs.read(fd, nil, rpos, onRead)
	else
		fs.read(fd, nil, rpos, onReadRecover)
	end
end

tail()

-- I don't know how tail -f does it on Windows but it has a very slight
-- delay sometimes, so it may very well be polling
t = timer.setInterval(500, function()
	fs.read(fd, nil, rpos-1, onRead)
end)

-- sock = require("net").connect(54197, "127.0.0.1", function(a) print("Socket connected") end)
sock = require("net").connect(54197, "127.0.0.1")

maxSocketPayloadSize = 2048

function say(str)
	if not str:match("[^ ]") then return end
	local payload = string.format('{"type":"CHAT","body":%s}\n', json.stringify(tostring(str)))
	if #payload > maxSocketPayloadSize then
		print(string.format("%sPayload is over %s byte limit%s", c.g, maxSocketPayloadSize, c.r))
	end
	sock:write(payload)
end

local repl = require("repl")(process.stdin.handle, process.stdout.handle, "REPL active", env).start(nil, nil, columns)
homeClear = repl.homeClear
refreshLine = repl.refreshLine
