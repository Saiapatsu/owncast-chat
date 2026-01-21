json = require("json")
fs = require("fs")
timer = require("timer")
uv = require("uv")

local env = getfenv()

local c = {}
for k,v in pairs({
	--theme-color-users-0: #bc1a32;
	--theme-color-users-1: #b3b3b3;
	--theme-color-users-2: #96c832;
	--theme-color-users-3: #2e8b57;
	--theme-color-users-4: #5f9ea0;
	--theme-color-users-5: #daa520;
	--theme-color-users-6: #847cfe;
	--theme-color-users-7: #ff4500;
	[0] = "\022\031", -- 4 dark red
	[1] = "\001\030", -- 8 dark gray
	-- [1] = "\001\037", -- f white
	[2] = "\001\032", -- a light green
	[3] = "\022\032", -- 2 dark green
	[4] = "\022\036", -- 3 dark aqua
	[5] = "\022\033", -- 6 gold/brown
	[6] = "\022\035", -- 5 dark purple
	[7] = "\001\031", -- c light red
	
	g = "\001\030", -- dark gray, subdued
	w = "\001\037", -- white, highlighted
	x = "\001\031", -- light red, danger
	r = "\000", -- reset
}) do
	-- Expand each byte to numerals, separate with ;
	c[k] = ("\027[%sm"):format(v:gsub(".", function(x) return tostring(string.byte(x)) .. ";" end):sub(1, -2))
end

-- https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b
c.up = "\027[1A" -- "moves cursor up # lines"

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
	renamefmt = "\r%s%" .. gutter-1 .. "s%s renamed from %s%s"
	wrapfind = string.rep(".", columns - gutter)
	spaces = string.rep(" ", gutter)
	spaces1 = "%1" .. spaces
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
		return "\n" .. spaces
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

-- TODO if line ends at screen width, do not emit newline or spaces i.e. don't make an empty line
-- TODO don't even print a newline at the end unless about to write a message so it stays flush with the bottom? Oh but the caret's there and it's gonna FEEL WRONG like there's more messages you can't see
-- You can also send just newlines so deal with those too
local function gutterwrap(str, x)
	-- Line wrapping
	-- UTF-8 unaware for the time being
	-- x: position on screen
	-- iw: must write if exceeding this
	-- foo: last unwritten pos in string
	-- local foo = 1
	-- local iw = columns - x + 1
	-- local lastword = 0
	-- local rope = {}
	-- for a, b in str:gmatch("()[^ ]+()") do
		-- if b > iw then
			-- -- Went past the end
			-- table.insert(rope, str:sub(foo, lastword))
			-- table.insert(rope, string.rep())
		-- end
	-- end
	
	str = neaten(str)
	if #str > columns - x then
		return str:sub(1, columns - x) .. spaces .. str:sub(columns - x + 1):gsub(wrapfind, spaces1)
	else
		return str
	end
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
	return renames[user.id] or str
end

local function ucolor(user)
	return c[user.displayColor] or c.g
end

-- local lastid = nil
		-- local name = x.user.id == lastid
			-- and spaces:sub(2) -- dangit
			-- or uanon(x.user)
		-- lastid = x.user.id -- feels wrong

function fence(str)
	local half = (columns - #str - 2) / 2
	return string.format("%s %s %s", string.rep("-", math.ceil(half)), str, string.rep("-", math.floor(half)))
end

local lastHour = nil
-- timestamp":"2026-01-19T23:53:58.051312309Z

function line(str)
	local x = json.parse(str)
	
	if type(x) ~= "table" then
		print(string.format("\r%s%s%s%s %s %s|%s%s%s|%s\n%s%s%s%s"
			, c.x, fence("Failed to parse JSON"), c.r
			, type(str), type(x), c.x, c.r, str, c.x, c.r
			, c.x, string.rep("-", columns), c.r, c.up
		))
		return
	end
	
	if x.timestamp then
		local hour = x.timestamp:sub(1, 13)
		if hour ~= lastHour then
			lastHour = hour
			local str = x.timestamp:sub(1, 16):gsub("T", " ")
			print(string.format("%s%s%s%s", c.g, fence(str), c.up, c.r))
		end
	end
	
	if x.type == "CHAT" then
		local color = ucolor(x.user)
		local name = uanon(x.user)
		print(string.format(chatfmt, color, name, c.r, gutterwrap(x.body, math.max(#name + 1, gutter)), c.r))
		
	elseif x.type == "NAME_CHANGE" then
		local color = ucolor(x.user)
		local oldname = uanon(x.user, x.oldName)
		local name = uanon(x.user)
		print(string.format(renamefmt, color, name, c.g, oldname, c.r))
		
	elseif x.type == "CHAT_ACTION" then
		print(string.format("\r%s%s%s%s", c.g, fence(neaten(x.body)), c.r, c.up))
		
	elseif x.type == "CONNECTED_USER_INFO" then
		local color = ucolor(x.user)
		local name = uanon(x.user)
		print(string.format("\r%sConnected as %s%s%s", c.g, color, name, c.r))
		
	else
		print(string.format("\r%s<%s> %s%s", c.g, x.type, str, c.r))
	end
end

local lastline
local function handleError(e)
	print(debug.traceback(e, 2))
	print(line)
end

function line2(str)
	lastline = str
	xpcall(line, handleError, str)
end

-- for str in io.lines() do
	-- xpcall(line, handleError, str)
-- end

-- Get filename of last log (wiping off the newline...) and open it
local name = fs.readFileSync("data/wss-last.txt"):match("[^\r\n]+")
local fd = fs.openSync(name, "r")

-- Timer handle
local t
-- Half-read line
local half = ""
-- File read position because read(pos) won't affect read()'s own seek point ???
local rpos = 0

local function onRead(err, str)
	if err then return timer.clearInterval(t) end
	if str == "" then return end
	
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
	fs.read(fd, nil, rpos, onRead)
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
	fs.read(fd, nil, rpos, onRead)
end)

-- sock = require("net").connect(54197, "127.0.0.1", function(a) print("Socket connected") end)
sock = require("net").connect(54197, "127.0.0.1")

function say(str)
	if not str:match("[^ ]") then return end
	local payload = string.format('{"type":"CHAT","body":%s}\n', json.stringify(tostring(str)))
	sock:write(payload)
end

require("repl")(process.stdin.handle, process.stdout.handle, "REPL active", env).start()
