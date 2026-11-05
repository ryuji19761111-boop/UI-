-- 最小限の Roblox API モック (ライブラリの実行時エラーを洗い出す用)
math.clamp = function(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function typeofImpl(v)
	if type(v) == "table" and rawget(v, "__type") then
		return v.__type
	end
	return type(v)
end
typeof = typeofImpl
warn = function(...) print("[warn]", ...) end

-- Signals ---------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ conns = {} }, Signal)
end
function Signal:Connect(fn)
	local c = { fn = fn, connected = true }
	function c:Disconnect() self.connected = false end
	table.insert(self.conns, c)
	return c
end
function Signal:Fire(...)
	for _, c in ipairs(self.conns) do
		if c.connected then c.fn(...) end
	end
end
MockSignal = Signal

-- Data types -------------------------------------------------------------
UDim = { new = function(s, o) return { __type = "UDim", Scale = s or 0, Offset = o or 0 } end }
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return { __type = "UDim2", X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
Vector2 = { new = function(x, y) return { __type = "Vector2", X = x or 0, Y = y or 0 } end }
Vector3 = { new = function(x, y, z) return { __type = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 } end }
Rect = { new = function(a, b, c, d) return { __type = "Rect" } end }

local C3 = {}
C3.__index = C3
function C3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
	end
	local s = mx == 0 and 0 or d / mx
	return h, s, mx
end
C3.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
Color3 = {}
function Color3.new(r, g, b) return setmetatable({ __type = "Color3", R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	local r, g, b
	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	else r, g, b = v, p, q end
	return Color3.new(r, g, b)
end
ColorSequence = { new = function(...) return { __type = "ColorSequence", ... } end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberSequence = { new = function(...) return { __type = "NumberSequence", ... } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
TweenInfo = { new = function(...) return { ... } end }

-- Enum ---------------------------------------------------------------------
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		if enumCache[enumName] then
			return enumCache[enumName]
		end
		local items = {}
		local e = setmetatable({}, {
			__index = function(_, itemName)
				if not items[itemName] then
					items[itemName] = { __type = "EnumItem", Name = itemName, EnumType = enumName }
				end
				return items[itemName]
			end,
		})
		enumCache[enumName] = e
		return e
	end,
})
rawset(Enum, "Font", nil)

-- Instance -------------------------------------------------------------------
local EVENTS = {
	InputBegan = true, InputEnded = true, InputChanged = true, MouseEnter = true, MouseLeave = true,
	Activated = true, Focused = true, FocusLost = true, ChildAdded = true,
}
local GUI = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true,
	ScrollingFrame = true, CanvasGroup = true,
}
local created = 0
local methods = {}

function methods.IsA(self, cls)
	local c = rawget(self, "_class")
	if c == cls then return true end
	if cls == "GuiObject" and GUI[c] then return true end
	if cls == "GuiButton" and (c == "TextButton" or c == "ImageButton") then return true end
	return false
end
function methods.GetChildren(self) local out = {} for _, c in ipairs(rawget(self, "_children")) do out[#out + 1] = c end return out end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n) for _, c in ipairs(rawget(n, "_children")) do out[#out + 1] = c walk(c) end end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name)
	for _, c in ipairs(rawget(self, "_children")) do
		if rawget(c, "_props").Name == name then return c end
	end
	return nil
end
function methods.WaitForChild(self, name)
	return methods.FindFirstChild(self, name) or error("WaitForChild: " .. tostring(name) .. " not found")
end
function methods.GetPropertyChangedSignal(self, prop)
	local sigs = rawget(self, "_propSignals")
	sigs[prop] = sigs[prop] or Signal.new()
	return sigs[prop]
end
function methods.IsFocused(self) return false end
function methods.CaptureFocus(self) end
function methods.Destroy(self)
	if rawget(self, "_destroyed") then return end
	rawset(self, "_destroyed", true)
	local parent = rawget(self, "_props").Parent
	if parent then
		local list = rawget(parent, "_children")
		for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
	end
	rawget(self, "_props").Parent = nil
	for _, c in ipairs(methods.GetChildren(self)) do methods.Destroy(c) end
end

local defaults = {
	Visible = true, Rotation = 0, ZIndex = 1, Text = "", AbsoluteSize = Vector2.new(200, 100),
	AbsolutePosition = Vector2.new(0, 0), AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0), ScrollingEnabled = true,
}
local InstanceMT = {}
InstanceMT.__index = function(self, k)
	if methods[k] then return methods[k] end
	local props = rawget(self, "_props")
	if props[k] ~= nil then return props[k] end
	if EVENTS[k] then
		props[k] = Signal.new()
		return props[k]
	end
	if k == "ClassName" then return rawget(self, "_class") end
	if k == "AbsoluteSize" and rawget(self, "_class") == "ScreenGui" then return Vector2.new(1280, 720) end
	return defaults[k]
end
InstanceMT.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "_children"), self) end
		return
	end
	props[k] = v
	local sigs = rawget(self, "_propSignals")
	if sigs[k] then sigs[k]:Fire() end
end

Instance = {}
function Instance.new(class)
	created = created + 1
	local inst = setmetatable({ _class = class, _children = {}, _props = { Name = class }, _propSignals = {} }, InstanceMT)
	return inst
end
function MockInstanceCount() return created end

-- Services ----------------------------------------------------------------------
local playerGui = Instance.new("PlayerGui")
local localPlayer = {
	Name = "Tester", DisplayName = "Tester", UserId = 1,
}
local services = {}
services.Players = {
	LocalPlayer = localPlayer,
	GetUserThumbnailAsync = function() return "rbxthumb://x" end,
}
localPlayer.WaitForChild = function(_, name) return playerGui end
services.TweenService = {
	Create = function(_, inst, info, props)
		return { Play = function() for k, v in pairs(props) do inst[k] = v end end }
	end,
}
services.UserInputService = {
	TouchEnabled = false,
	InputBegan = Signal.new(), InputEnded = Signal.new(), InputChanged = Signal.new(),
}

-- JSON (最小限)
local function jenc(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do parts[#parts + 1] = jenc(x) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do parts[#parts + 1] = string.format("%q:%s", k, jenc(x)) end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then return string.format("%q", v)
	elseif t == "number" or t == "boolean" then return tostring(v) end
	return "null"
end
local function jdec(s)
	local pos = 1
	local function ws() pos = s:find("%S", pos) or #s + 1 end
	local val
	local function str()
		local e = s:find('"', pos + 1, true)
		local r = s:sub(pos + 1, e - 1)
		pos = e + 1
		return r
	end
	function val()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local out = {}
			pos = pos + 1; ws()
			if s:sub(pos, pos) == "}" then pos = pos + 1 return out end
			while true do
				ws(); local k = str(); ws(); pos = pos + 1
				out[k] = val(); ws()
				local d = s:sub(pos, pos); pos = pos + 1
				if d == "}" then return out end
			end
		elseif c == "[" then
			local out = {}
			pos = pos + 1; ws()
			if s:sub(pos, pos) == "]" then pos = pos + 1 return out end
			while true do
				out[#out + 1] = val(); ws()
				local d = s:sub(pos, pos); pos = pos + 1
				if d == "]" then return out end
			end
		elseif c == '"' then return str()
		elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local n = s:match("^-?[%d%.eE+-]+", pos)
			pos = pos + #n
			return tonumber(n)
		end
	end
	return val()
end
services.HttpService = {
	JSONEncode = function(_, v) return jenc(v) end,
	JSONDecode = function(_, s) return jdec(s) end,
}
game = { GetService = function(_, name) return services[name] or error("no service " .. name) end }
workspace = { CurrentCamera = { ViewportSize = Vector2.new(1280, 720) } }
MockServices = services
MockPlayerGui = playerGui

-- task -----------------------------------------------------------------------------
local queue = {}
task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) local a = { ... } queue[#queue + 1] = function() fn(table.unpack(a)) end end,
	delay = function(_, fn) queue[#queue + 1] = fn end,
	wait = function() return 0 end,
}
function MockFlush()
	local n = 0
	while #queue > 0 and n < 1000 do
		local f = table.remove(queue, 1)
		f()
		n = n + 1
	end
end
