--[[
	ONYX UI  v1.0.0  (Client)
	Roblox 用 UI ライブラリ ― 黒基調・白文字の落ち着いたデザイン (クライアント側専用)

	  • ウィンドウ: ドラッグ / リサイズ / 最小化 / 開閉アニメ / 検索 / スマホ用フローティングボタン
	  • タブ・セクション・ラベル・段落・区切り線
	  • Button / Toggle / Slider / Dropdown(複数選択) / Input / Keybind / ColorPicker
	  • 通知、ダイアログ、テーマ 7 種 + アクセントカラー変更 + 自作テーマ
	  • Flags / Options、設定の JSON 書き出し・読み込み

	使い方は README.md と examples/Demo.client.lua を参照。
	License: MIT
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Onyx = { Version = "1.0.0", Windows = {}, Parent = nil }
local Window, Tab = {}, {}
Window.__index = Window
Tab.__index = Tab

local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local MONO = Enum.Font.Code
local MED = Enum.Font.GothamMedium
local SEMI = Enum.Font.GothamSemibold
local BOLD = Enum.Font.GothamBold

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local BaseTheme = {
	Background = rgb(14, 14, 16),
	Sidebar = rgb(11, 11, 13),
	Surface = rgb(19, 19, 21),
	Hover = rgb(24, 24, 27),
	Control = rgb(14, 14, 16),
	Popup = rgb(18, 18, 20),
	Stroke = rgb(31, 31, 35),
	StrokeStrong = rgb(44, 44, 49),
	Text = rgb(242, 242, 243),
	SubText = rgb(139, 139, 146),
	Muted = rgb(154, 154, 162),
	Accent = rgb(242, 242, 243),
	OnAccent = rgb(10, 10, 10),
	Track = rgb(42, 42, 46),
	Success = rgb(88, 200, 120),
	Warning = rgb(232, 184, 72),
	Danger = rgb(232, 86, 96),
}

local function Copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function OnColor(c)
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	if l > 0.55 then
		return rgb(10, 10, 10)
	end
	return rgb(250, 250, 250)
end

local function Variant(overrides)
	local t = Copy(BaseTheme)
	for k, v in pairs(overrides) do
		t[k] = v
	end
	if overrides.Accent and not overrides.OnAccent then
		t.OnAccent = OnColor(overrides.Accent)
	end
	return t
end

local Themes = {
	Onyx = Copy(BaseTheme),
	Graphite = Variant({
		Background = rgb(24, 24, 27),
		Sidebar = rgb(20, 20, 23),
		Surface = rgb(31, 31, 35),
		Hover = rgb(38, 38, 43),
		Control = rgb(24, 24, 27),
		Popup = rgb(28, 28, 32),
		Stroke = rgb(46, 46, 52),
		StrokeStrong = rgb(62, 62, 70),
		Track = rgb(58, 58, 64),
	}),
	Ice = Variant({ Accent = rgb(125, 211, 252) }),
	Lime = Variant({ Accent = rgb(163, 230, 53) }),
	Amber = Variant({ Accent = rgb(253, 186, 116) }),
	Rose = Variant({ Accent = rgb(251, 113, 133) }),
	Violet = Variant({ Accent = rgb(167, 139, 250) }),
}
Onyx.Themes = Themes

local function ResolveTheme(t)
	if type(t) == "table" then
		local out = Copy(Themes[t.Base or "Onyx"] or Themes.Onyx)
		for k, v in pairs(t) do
			if k ~= "Base" then
				out[k] = v
			end
		end
		if t.Accent and not t.OnAccent then
			out.OnAccent = OnColor(t.Accent)
		end
		return out
	end
	return Copy(Themes[t or "Onyx"] or Themes.Onyx)
end

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------
local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function New(class, props, children)
	local inst = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		inst.Font = MED
		inst.TextSize = 13
	end
	if class == "TextLabel" or class == "ImageLabel" or class == "ScrollingFrame" then
		inst.BackgroundTransparency = 1
	end
	if class == "TextButton" or class == "ImageButton" then
		inst.AutoButtonColor = false
	end
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function Stroke(color, thickness, transparency)
	return New("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Pad(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
	})
end

local function List(padding)
	return New("UIListLayout", { Padding = UDim.new(0, padding or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function Safe(fn, ...)
	if type(fn) == "function" then
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Onyx] callback error: " .. tostring(err))
		end
	end
end

local function Opts(o)
	if type(o) == "string" then
		return { Name = o }
	end
	return o or {}
end

local function Round(n, d)
	local m = 10 ^ d
	return math.floor(n * m + 0.5) / m
end

local function DecimalsOf(n)
	local s = tostring(n)
	local dot = s:find("%.")
	return dot and (#s - dot) or 0
end

local function ToHex(c)
	return string.format(
		"#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function FromHex(s)
	if type(s) ~= "string" then
		return nil
	end
	s = s:gsub("#", "")
	if #s ~= 6 then
		return nil
	end
	local r, g, b = tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16)
	if r and g and b then
		return Color3.fromRGB(r, g, b)
	end
	return nil
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function GetTargetParent()
	return Onyx.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- 小さな図形アイコン (フォントに依存しない)
local function MakeChevron(parent, position)
	local c = New("Frame", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position or UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local arms = {}
	for i, rot in ipairs({ 45, -45 }) do
		arms[i] = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(i == 1 and 4 or 8, 6),
			Size = UDim2.fromOffset(6, 2),
			Rotation = rot,
			BackgroundColor3 = WHITE,
			Parent = c,
		}, { Corner(1) })
	end
	return c, arms
end

local function MakeLogo(win, parent, size, position, anchor)
	local holder = New("Frame", {
		Name = "Logo",
		AnchorPoint = anchor or Vector2.new(0, 0),
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local diamond = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.66, size * 0.66),
		Rotation = 45,
		BackgroundTransparency = 1,
		Parent = holder,
	}, { Corner(2) })
	local stroke = Stroke(win.Theme.Accent, 1.6)
	stroke.Parent = diamond
	local dot = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.2, size * 0.2),
		Parent = holder,
	}, { Corner(size) })
	win:_bind(stroke, "Color", "Accent")
	win:_bind(dot, "BackgroundColor3", "Accent")
	return holder
end

----------------------------------------------------------------------
-- Overlay: notifications
----------------------------------------------------------------------
local overlay
local notifyCounter = 0

local function GetOverlay()
	if overlay and overlay.Parent then
		return overlay
	end
	overlay = New("ScreenGui", {
		Name = "Onyx_Overlay",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		Parent = GetTargetParent(),
	})
	local cam = workspace.CurrentCamera
	local vpx = cam and cam.ViewportSize.X or 1280
	New("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, math.min(272, vpx - 32), 1, -32),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	return overlay
end

--- 通知を出す
--- Onyx:Notify({ Title = "保存しました", Content = "設定を適用", Type = "Success", Duration = 4 })
function Onyx:Notify(opts)
	opts = Opts(opts)
	local theme = Onyx._theme or Themes.Onyx
	local colors = {
		Info = theme.Accent,
		Success = theme.Success,
		Warning = theme.Warning,
		Error = theme.Danger,
	}
	local bar = colors[opts.Type or "Info"] or colors.Info
	local duration = opts.Duration or 4
	local gui = GetOverlay()
	local holder = gui:FindFirstChild("Notifications")

	-- 古い通知を整理 (最大 5 件)
	local live = {}
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(live, c)
		end
	end
	if #live >= 5 then
		live[1]:Destroy()
	end

	notifyCounter = notifyCounter + 1
	local wrap = New("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = notifyCounter,
		Parent = holder,
	})
	local card = New("TextButton", {
		Name = "Card",
		Position = UDim2.new(1.2, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Popup,
		ClipsDescendants = true,
		Text = "",
		Parent = wrap,
	}, { Corner(10), Stroke(theme.StrokeStrong, 1) })
	New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = bar, Parent = card })
	local body = New("Frame", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -18, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { List(3), Pad(0, 12, 14, 13) })
	local head = New("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = body,
	})
	New("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0),
		Text = opts.Title or opts.Name or "Onyx",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = SEMI,
		TextSize = 13,
		TextColor3 = theme.Text,
		Parent = head,
	})
	New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 36, 1, 0),
		Text = "now",
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = MONO,
		TextSize = 10,
		TextColor3 = theme.Muted,
		Parent = head,
	})
	if opts.Content and opts.Content ~= "" then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextSize = 12,
			TextColor3 = theme.Muted,
			LayoutOrder = 2,
			Parent = body,
		})
	end
	local timer = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = bar,
		BackgroundTransparency = 0.5,
		Parent = card,
	})

	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.4, Enum.EasingStyle.Quint)
	Tween(timer, { Size = UDim2.new(0, 0, 0, 1) }, duration, Enum.EasingStyle.Linear)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Tween(card, { Position = UDim2.new(1.2, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.35, function()
			wrap:Destroy()
		end)
	end
	card.Activated:Connect(close)
	task.delay(duration, close)
	return { Close = close }
end

----------------------------------------------------------------------
-- Window internals
----------------------------------------------------------------------
function Window:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

function Window:_bind(inst, prop, key)
	table.insert(self._bindings, { inst = inst, prop = prop, key = key })
	inst[prop] = self.Theme[key]
	return inst
end

function Window:_onTheme(fn)
	table.insert(self._hooks, fn)
end

function Window:_refresh()
	Onyx._theme = self.Theme
	for i = #self._bindings, 1, -1 do
		local b = self._bindings[i]
		if b.inst.Parent == nil then
			table.remove(self._bindings, i)
		else
			Tween(b.inst, { [b.prop] = self.Theme[b.key] }, 0.25)
		end
	end
	for _, fn in ipairs(self._hooks) do
		Safe(fn)
	end
end

function Window:SetTheme(theme)
	self.Theme = ResolveTheme(theme)
	self:_refresh()
end

function Window:SetAccent(color)
	self.Theme.Accent = color
	self.Theme.OnAccent = OnColor(color)
	self:_refresh()
end

function Window:Notify(opts)
	Onyx._theme = self.Theme
	return Onyx:Notify(opts)
end

function Window:_beginDrag(onMove, onEnd)
	self._drag = { move = onMove, finish = onEnd }
end

-- handle を押して target を動かす (クリックだけなら onClick)
local function AttachDrag(win, handle, target, onClick)
	handle.InputBegan:Connect(function(input)
		if not IsPress(input) then
			return
		end
		local sx, sy = input.Position.X, input.Position.Y
		local startPos = target.Position
		local abs, size, anchor = target.AbsolutePosition, target.AbsoluteSize, target.AnchorPoint
		local cx0 = abs.X + size.X * anchor.X
		local cy0 = abs.Y + size.Y * anchor.Y
		local moved = false
		win:_beginDrag(function(i)
			local dx, dy = i.Position.X - sx, i.Position.Y - sy
			if math.abs(dx) + math.abs(dy) > 5 then
				moved = true
			end
			local vp = win._gui.AbsoluteSize
			local cx = math.clamp(cx0 + dx, 40, math.max(vp.X - 40, 41))
			local cy = math.clamp(cy0 + dy, 24, math.max(vp.Y - 24, 25))
			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (cx - cx0),
				startPos.Y.Scale,
				startPos.Y.Offset + (cy - cy0)
			)
		end, function()
			if onClick and not moved then
				onClick()
			end
		end)
	end)
end

function Window:_applyFilter()
	local q = string.lower(self._query or "")
	for _, tab in ipairs(self.Tabs) do
		local cur, count = nil, 0
		local function closeSection()
			if cur then
				cur.card.Visible = (not cur.userHidden) and (q == "" or count > 0)
			end
		end
		for _, item in ipairs(tab._items) do
			if item.kind == "Section" then
				closeSection()
				cur, count = item, 0
			else
				local match = (q == "") or (item.text:find(q, 1, true) ~= nil)
				local visible = match and not item.userHidden
				item.card.Visible = visible
				if visible then
					count = count + 1
				end
			end
		end
		closeSection()
	end
end

function Window:Show()
	if self._destroyed or self._visible then
		return
	end
	self._visible = true
	self._holder.Visible = true
	self._main.GroupTransparency = 1
	self._shadow.ImageTransparency = 1
	self._outline.Transparency = 1
	self._scale.Scale = 0.94
	Tween(self._outline, { Transparency = 0 }, 0.25)
	Tween(self._scale, { Scale = 1 }, 0.35, Enum.EasingStyle.Quint)
	Tween(self._main, { GroupTransparency = 0 }, 0.25)
	Tween(self._shadow, { ImageTransparency = 0.4 }, 0.3)
end

function Window:Hide()
	if not self._visible then
		return
	end
	self._visible = false
	Tween(self._scale, { Scale = 0.96 }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(self._main, { GroupTransparency = 1 }, 0.18)
	Tween(self._shadow, { ImageTransparency = 1 }, 0.18)
	Tween(self._outline, { Transparency = 1 }, 0.18)
	task.delay(0.22, function()
		if not self._visible and self._holder then
			self._holder.Visible = false
		end
	end)
end

function Window:Toggle()
	if self._visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

function Window:SetMinimized(state)
	self._minimized = state and true or false
	if self._minimized then
		self._grip.Visible = false
		Tween(self._holder, { Size = UDim2.fromOffset(self._w, 48) }, 0.3, Enum.EasingStyle.Quint)
		task.delay(0.3, function()
			if self._minimized then
				self._body.Visible = false
			end
		end)
	else
		self._body.Visible = true
		self._grip.Visible = self._resizable
		Tween(self._holder, { Size = UDim2.fromOffset(self._w, self._h) }, 0.35, Enum.EasingStyle.Quint)
	end
end

function Window:SelectTab(tab)
	if self._active == tab then
		return
	end
	local t = self.Theme
	local old = self._active
	if old then
		old._page.Visible = false
		Tween(old._btn, { BackgroundTransparency = 1 }, 0.15)
		Tween(old._bar, { BackgroundTransparency = 1 }, 0.15)
		if old._label then
			Tween(old._label, { TextColor3 = t.SubText }, 0.15)
		end
		old._setIcon(t.SubText)
		old._active = false
	end
	self._active = tab
	tab._active = true
	tab._page.Position = UDim2.fromOffset(0, 10)
	tab._page.Visible = true
	Tween(tab._page, { Position = UDim2.fromOffset(0, 0) }, 0.28)
	Tween(tab._btn, { BackgroundTransparency = 0 }, 0.15)
	Tween(tab._bar, { BackgroundTransparency = 0 }, 0.15)
	if tab._label then
		Tween(tab._label, { TextColor3 = t.Text }, 0.15)
	end
	tab._setIcon(t.Text)
end

--- タブを追加  Window:AddTab({ Name = "Home", Icon = "rbxassetid://123" })
--- Icon は省略可 (省略時は小さな図形アイコン)。1〜2 文字の文字列も可。
function Window:AddTab(opts)
	opts = Opts(opts)
	local name = opts.Name or ("Tab " .. (#self.Tabs + 1))
	local tab = setmetatable({ _window = self, _order = 0, _items = {}, Name = name }, Tab)

	local btn = New("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Tabs + 1,
		Parent = self._tabList,
	}, { Corner(8) })
	self:_bind(btn, "BackgroundColor3", "Hover")
	local bar = New("Frame", {
		Name = "Bar",
		Position = UDim2.new(0, 0, 0.5, -9),
		Size = UDim2.fromOffset(2, 18),
		BackgroundTransparency = 1,
		Parent = btn,
	}, { Corner(2) })
	self:_bind(bar, "BackgroundColor3", "Accent")

	local iconX = self._compact and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
	local iconAnchor = Vector2.new(self._compact and 0.5 or 0, 0.5)
	local icon = opts.Icon
	if type(icon) == "number" then
		icon = "rbxassetid://" .. tostring(icon)
	end
	if type(icon) == "string" and icon:sub(1, 13) == "rbxassetid://" then
		local img = New("ImageLabel", {
			AnchorPoint = iconAnchor,
			Position = iconX,
			Size = UDim2.fromOffset(18, 18),
			Image = icon,
			ImageColor3 = self.Theme.SubText,
			Parent = btn,
		})
		tab._setIcon = function(c)
			Tween(img, { ImageColor3 = c }, 0.15)
		end
	elseif type(icon) == "string" and icon ~= "" then
		local glyph = New("TextLabel", {
			AnchorPoint = iconAnchor,
			Position = iconX,
			Size = UDim2.fromOffset(18, 18),
			Text = icon,
			Font = BOLD,
			TextSize = 14,
			TextColor3 = self.Theme.SubText,
			Parent = btn,
		})
		tab._setIcon = function(c)
			Tween(glyph, { TextColor3 = c }, 0.15)
		end
	else
		local ring = New("Frame", {
			AnchorPoint = iconAnchor,
			Position = iconX,
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			Parent = btn,
		}, { Corner(4) })
		local rs = Stroke(self.Theme.SubText, 1.6)
		rs.Parent = ring
		tab._setIcon = function(c)
			Tween(rs, { Color = c }, 0.15)
		end
	end

	if not self._compact then
		tab._label = New("TextLabel", {
			Position = UDim2.new(0, 40, 0, 0),
			Size = UDim2.new(1, -46, 1, 0),
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = SEMI,
			TextSize = 13,
			TextColor3 = self.Theme.SubText,
			Parent = btn,
		})
	end

	local page = New("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	}, { List(6), Pad(20, 16, 20, 16) })
	self:_bind(page, "ScrollBarImageColor3", "StrokeStrong")

	tab._btn, tab._bar, tab._page = btn, bar, page

	btn.MouseEnter:Connect(function()
		if not tab._active then
			Tween(btn, { BackgroundTransparency = 0.6 }, 0.12)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not tab._active then
			Tween(btn, { BackgroundTransparency = 1 }, 0.12)
		end
	end)
	btn.Activated:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

--- 設定の書き出し / 読み込み (Flag を付けた部品が対象)
function Window:ExportConfig()
	local data = {}
	for flag, opt in pairs(self.Options) do
		local v = opt.Value
		if opt.Type == "ColorPicker" and v then
			v = ToHex(v)
		elseif opt.Type == "Keybind" then
			v = v and v.Name or nil
		end
		data[flag] = v
	end
	return HttpService:JSONEncode(data)
end

function Window:ImportConfig(json)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	for flag, v in pairs(data) do
		local opt = self.Options[flag]
		if opt then
			if opt.Type == "ColorPicker" then
				v = FromHex(v)
			end
			if v ~= nil then
				opt:Set(v)
			end
		end
	end
	return true
end

--- 確認ダイアログ
--- Window:Dialog({ Title = "確認", Content = "本当にやる?", Buttons = { { Name = "やめる" }, { Name = "OK", Primary = true, Callback = fn } } })
function Window:Dialog(opts)
	opts = Opts(opts)
	local t = self.Theme
	local dim = New("TextButton", {
		Name = "DialogDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 40,
		Parent = self._main,
	})
	local scale = New("UIScale", { Scale = 0.94 })
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.min(330, self._w - 40), 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = t.Popup,
		Active = true,
		Parent = dim,
	}, { Corner(12), Stroke(t.StrokeStrong, 1), List(10), Pad(18, 16, 18, 16), scale })
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "Onyx",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = SEMI,
		TextSize = 15,
		TextColor3 = t.Text,
		LayoutOrder = 1,
		Parent = card,
	})
	if opts.Content and opts.Content ~= "" then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextSize = 12.5,
			TextColor3 = t.Muted,
			LayoutOrder = 2,
			Parent = card,
		})
	end
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = card,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local obj = {}
	local closed = false
	function obj:Close()
		if closed then
			return
		end
		closed = true
		Tween(dim, { BackgroundTransparency = 1 }, 0.15)
		Tween(scale, { Scale = 0.96 }, 0.15)
		task.delay(0.18, function()
			dim:Destroy()
		end)
	end

	local buttons = opts.Buttons or { { Name = "OK", Primary = true } }
	for i, b in ipairs(buttons) do
		local primary = b.Primary == true
		local bt = New("TextButton", {
			Size = UDim2.new(0, 0, 0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = primary and t.Accent or t.Popup,
			BackgroundTransparency = primary and 0 or 1,
			Text = b.Name or "OK",
			Font = SEMI,
			TextSize = 12.5,
			TextColor3 = primary and t.OnAccent or t.Text,
			LayoutOrder = i,
			Parent = row,
		}, { Corner(7), Pad(16, 0, 16, 0) })
		if not primary then
			Stroke(t.StrokeStrong, 1).Parent = bt
		end
		bt.Activated:Connect(function()
			Safe(b.Callback)
			obj:Close()
		end)
	end

	if opts.Dismissable ~= false then
		dim.Activated:Connect(function()
			obj:Close()
		end)
	end
	Tween(dim, { BackgroundTransparency = 0.45 }, 0.2)
	Tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Quint)
	return obj
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	self._conns = {}
	if self._gui then
		self._gui:Destroy()
	end
	for i, w in ipairs(Onyx.Windows) do
		if w == self then
			table.remove(Onyx.Windows, i)
			break
		end
	end
end

function Onyx:DestroyAll()
	for i = #Onyx.Windows, 1, -1 do
		Onyx.Windows[i]:Destroy()
	end
end

----------------------------------------------------------------------
-- CreateWindow
----------------------------------------------------------------------
--[[
	Onyx:CreateWindow({
		Title = "ONYX", Subtitle = "client · v1.0",
		Theme = "Onyx" | "Graphite" | "Ice" | "Lime" | "Amber" | "Rose" | "Violet" | { Base = "Onyx", Accent = Color3 },
		Size = UDim2.fromOffset(760, 480),
		ToggleKey = Enum.KeyCode.RightShift,
		Search = true,           -- タイトルバーの検索
		Resizable = true,        -- 右下でサイズ変更
		UserCard = true,         -- サイドバー下のプレイヤー表示
		FloatingButton = nil,    -- nil = タッチ端末のみ表示 / true / false
	})
]]
function Onyx:CreateWindow(config)
	config = Opts(config)
	local self = setmetatable({}, Window)
	self.Title = config.Title or "ONYX"
	self.Subtitle = config.Subtitle
	if self.Subtitle == nil then
		self.Subtitle = "client · v" .. Onyx.Version
	end
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
	self.Theme = ResolveTheme(config.Theme)
	Onyx._theme = self.Theme
	self.Flags, self.Options, self.Tabs = {}, {}, {}
	self._bindings, self._hooks, self._conns = {}, {}, {}
	self._visible, self._minimized, self._destroyed = false, false, false
	self._query = ""
	self._resizable = config.Resizable ~= false

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w, h = 760, 480
	if config.Size then
		w, h = config.Size.X.Offset, config.Size.Y.Offset
	end
	w = math.min(w, vp.X - 24)
	h = math.min(h, vp.Y - 24)
	self._w, self._h = w, h
	self._compact = w < 560
	local sideW = self._compact and 58 or 176

	local gui = New("ScreenGui", {
		Name = "Onyx_" .. self.Title,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = config.DisplayOrder or 100,
		Parent = config.Parent or GetTargetParent(),
	})
	self._gui = gui

	local holder = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local scale = New("UIScale", { Scale = 0.94, Parent = holder })
	local shadow = New("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 70, 1, 70),
		Image = "rbxassetid://6014261993",
		ImageColor3 = BLACK,
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
		Parent = holder,
	})
	local main = New("CanvasGroup", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, { Corner(14) })
	self:_bind(main, "BackgroundColor3", "Background")
	-- 枠線は CanvasGroup の外側に描く (グループ内だと端が欠けるため)
	local outline = New("Frame", {
		Name = "Outline",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	}, { Corner(14) })
	local outlineStroke = Stroke(self.Theme.StrokeStrong, 1)
	outlineStroke.Parent = outline
	self:_bind(outlineStroke, "Color", "StrokeStrong")
	self._holder, self._scale, self._shadow, self._main = holder, scale, shadow, main
	self._outline = outlineStroke

	-- 上端のうっすらした光
	local glow = New("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.76, 0, 0, 1),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = main,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	})

	-- Title bar -----------------------------------------------------
	local top = New("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 48),
		Active = true,
		Parent = main,
	})
	self:_bind(top, "BackgroundColor3", "Background")
	local topLine = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = top,
	})
	self:_bind(topLine, "BackgroundColor3", "Stroke")

	local left = New("Frame", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local logoSlot = New("Frame", {
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = left,
	})
	MakeLogo(self, logoSlot, 20)
	local titleL = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = self.Title,
		Font = BOLD,
		TextSize = 14,
		LayoutOrder = 2,
		Parent = left,
	})
	self:_bind(titleL, "TextColor3", "Text")
	if self.Subtitle ~= "" and not self._compact then
		local subL = New("TextLabel", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = self.Subtitle,
			Font = MONO,
			TextSize = 11,
			LayoutOrder = 3,
			Parent = left,
		})
		self:_bind(subL, "TextColor3", "Muted")
	end

	local function iconButton(order)
		local b = New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = order,
			Parent = nil,
		}, { Corner(7) })
		self:_bind(b, "BackgroundColor3", "Hover")
		b.MouseEnter:Connect(function()
			Tween(b, { BackgroundTransparency = 0 }, 0.12)
		end)
		b.MouseLeave:Connect(function()
			Tween(b, { BackgroundTransparency = 1 }, 0.12)
		end)
		return b
	end
	local btnRow = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(60, 28),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local minBtn = iconButton(1)
	minBtn.Parent = btnRow
	local minLine = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 2),
		Parent = minBtn,
	}, { Corner(1) })
	self:_bind(minLine, "BackgroundColor3", "Muted")
	local closeBtn = iconButton(2)
	closeBtn.Parent = btnRow
	for _, rot in ipairs({ 45, -45 }) do
		local arm = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 2),
			Rotation = rot,
			Parent = closeBtn,
		}, { Corner(1) })
		self:_bind(arm, "BackgroundColor3", "Muted")
	end
	minBtn.Activated:Connect(function()
		self:SetMinimized(not self._minimized)
	end)
	closeBtn.Activated:Connect(function()
		self:Hide()
		if not self._hintShown and not UserInputService.TouchEnabled then
			self._hintShown = true
			Onyx._theme = self.Theme
			Onyx:Notify({
				Title = "Window hidden",
				Content = "Press " .. self.ToggleKey.Name .. " to open it again.",
				Duration = 3,
			})
		end
	end)

	-- 検索
	if config.Search ~= false and w >= 640 then
		local searchBox = New("TextBox", {
			Name = "Search",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -84, 0.5, 0),
			Size = UDim2.fromOffset(150, 28),
			Text = "",
			PlaceholderText = "Search…",
			ClearTextOnFocus = false,
			Font = MONO,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = top,
		}, { Corner(7), Pad(10, 0, 10, 0) })
		self:_bind(searchBox, "BackgroundColor3", "Control")
		self:_bind(searchBox, "TextColor3", "Text")
		self:_bind(searchBox, "PlaceholderColor3", "SubText")
		local ss = Stroke(self.Theme.StrokeStrong, 1)
		ss.Parent = searchBox
		self:_bind(ss, "Color", "StrokeStrong")
		searchBox.Focused:Connect(function()
			Tween(ss, { Color = self.Theme.Accent }, 0.15)
		end)
		searchBox.FocusLost:Connect(function()
			Tween(ss, { Color = self.Theme.StrokeStrong }, 0.15)
		end)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self._query = searchBox.Text
			self:_applyFilter()
		end)
		self._search = searchBox
	end

	AttachDrag(self, top, holder)

	-- Body ----------------------------------------------------------
	local body = New("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = main,
	})
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, sideW, 1, 0),
		Parent = body,
	})
	self:_bind(sidebar, "BackgroundColor3", "Sidebar")
	local sideLine = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})
	self:_bind(sideLine, "BackgroundColor3", "Stroke")

	local showUser = config.UserCard ~= false
	local chipH = showUser and 52 or 0
	local tabList = New("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, -1, 1, -chipH),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = sidebar,
	}, { List(4), Pad(12, 12, 12, 8) })

	if showUser then
		local plr = Players.LocalPlayer
		local chip = New("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -10),
			Size = UDim2.new(1, -21, 0, 40),
			Parent = sidebar,
		}, { Corner(9) })
		self:_bind(chip, "BackgroundColor3", "Background")
		local cs = Stroke(self.Theme.Stroke, 1)
		cs.Parent = chip
		self:_bind(cs, "Color", "Stroke")
		local avatar = New("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, self._compact and 7 or 8, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 0,
			Parent = chip,
		}, { Corner(13) })
		self:_bind(avatar, "BackgroundColor3", "Hover")
		local letter = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(plr and plr.DisplayName or "G", 1, 1)),
			Font = SEMI,
			TextSize = 12,
			Parent = avatar,
		})
		self:_bind(letter, "TextColor3", "Text")
		if not self._compact then
			local nameL = New("TextLabel", {
				Position = UDim2.fromOffset(42, 5),
				Size = UDim2.new(1, -48, 0, 15),
				Text = plr and plr.DisplayName or "Guest",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Font = SEMI,
				TextSize = 12,
				Parent = chip,
			})
			self:_bind(nameL, "TextColor3", "Text")
			local subL = New("TextLabel", {
				Position = UDim2.fromOffset(42, 20),
				Size = UDim2.new(1, -48, 0, 13),
				Text = "@" .. (plr and plr.Name or "guest"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Font = MONO,
				TextSize = 10,
				Parent = chip,
			})
			self:_bind(subL, "TextColor3", "Muted")
		end
		if plr then
			task.spawn(function()
				local ok, img = pcall(function()
					return Players:GetUserThumbnailAsync(
						plr.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size48x48
					)
				end)
				if ok and img and not self._destroyed then
					avatar.Image = img
					letter.Visible = false
				end
			end)
		end
	end

	local content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(sideW, 0),
		Size = UDim2.new(1, -sideW, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})
	self._body, self._tabList, self._content = body, tabList, content

	self:_onTheme(function()
		for _, tab in ipairs(self.Tabs) do
			local c = tab._active and self.Theme.Text or self.Theme.SubText
			if tab._label then
				tab._label.TextColor3 = c
			end
			tab._setIcon(c)
		end
	end)

	-- リサイズ用グリップ
	local grip = New("TextButton", {
		Name = "Grip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		Visible = self._resizable,
		Parent = main,
	})
	for i = 1, 2 do
		local g = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, i * 2 - 1, 0.5, i * 2 - 1),
			Size = UDim2.fromOffset(i == 1 and 6 or 12, 1),
			Rotation = -45,
			BackgroundTransparency = 0.2,
			Parent = grip,
		})
		self:_bind(g, "BackgroundColor3", "StrokeStrong")
	end
	self._grip = grip
	grip.InputBegan:Connect(function(input)
		if not IsPress(input) or self._minimized then
			return
		end
		local sx, sy = input.Position.X, input.Position.Y
		local w0, h0 = self._w, self._h
		local startPos = holder.Position
		self:_beginDrag(function(i)
			local vps = gui.AbsoluteSize
			local nw = math.clamp(w0 + (i.Position.X - sx), 480, math.max(vps.X - 24, 481))
			local nh = math.clamp(h0 + (i.Position.Y - sy), 320, math.max(vps.Y - 24, 321))
			self._w, self._h = nw, nh
			holder.Size = UDim2.fromOffset(nw, nh)
			holder.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (nw - w0) / 2,
				startPos.Y.Scale,
				startPos.Y.Offset + (nh - h0) / 2
			)
		end)
	end)

	-- 入力 (ドラッグ共通処理 + 開閉キー)
	self:_connect(UserInputService.InputChanged, function(input)
		if self._drag and IsMove(input) then
			Safe(self._drag.move, input)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if self._drag and IsPress(input) then
			local d = self._drag
			self._drag = nil
			Safe(d.finish, input)
		end
	end)
	self:_connect(UserInputService.InputBegan, function(input, processed)
		if processed or self._destroyed or self._capturing then
			return
		end
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	-- フローティングボタン (スマホ)
	if config.FloatingButton == true or (config.FloatingButton == nil and UserInputService.TouchEnabled) then
		local fb = New("Frame", {
			Name = "FloatingButton",
			Position = UDim2.new(0, 14, 0.5, -23),
			Size = UDim2.fromOffset(46, 46),
			Active = true,
			Parent = gui,
		}, { Corner(14) })
		self:_bind(fb, "BackgroundColor3", "Background")
		local fs = Stroke(self.Theme.StrokeStrong, 1)
		fs.Parent = fb
		self:_bind(fs, "Color", "StrokeStrong")
		MakeLogo(self, fb, 26, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		AttachDrag(self, fb, fb, function()
			self:Toggle()
		end)
		self._floating = fb
	end

	table.insert(Onyx.Windows, self)
	if config.Visible ~= false then
		self:Show()
	end
	return self
end

Onyx.new = Onyx.CreateWindow

----------------------------------------------------------------------
-- Tab elements
----------------------------------------------------------------------
function Tab:_next()
	self._order = self._order + 1
	return self._order
end

function Tab:Select()
	self._window:SelectTab(self)
end

local function NewCard(tab, clickable, minH)
	local win = tab._window
	local props = {
		Name = "Element",
		Size = UDim2.new(1, 0, 0, minH or 46),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		LayoutOrder = tab:_next(),
		Parent = tab._page,
	}
	if clickable then
		props.Text = ""
	end
	local card = New(clickable and "TextButton" or "Frame", props, { Corner(9) })
	win:_bind(card, "BackgroundColor3", "Surface")
	local stroke = Stroke(win.Theme.Stroke, 1)
	stroke.Parent = card
	win:_bind(stroke, "Color", "Stroke")
	if clickable then
		card.MouseEnter:Connect(function()
			Tween(card, { BackgroundColor3 = win.Theme.Hover }, 0.12)
		end)
		card.MouseLeave:Connect(function()
			Tween(card, { BackgroundColor3 = win.Theme.Surface }, 0.12)
		end)
	end
	return card
end

local function RowText(win, parent, title, desc, rightPad)
	local hasDesc = desc ~= nil and desc ~= ""
	local vpad = hasDesc and 11 or 15
	local holder = New("Frame", {
		Name = "Text",
		Size = UDim2.new(1, -(rightPad or 0), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { List(2), Pad(14, vpad, 6, vpad) })
	local titleL = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = title or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = SEMI,
		TextSize = 13,
		LayoutOrder = 1,
		Parent = holder,
	})
	win:_bind(titleL, "TextColor3", "Text")
	local descL
	if hasDesc then
		descL = New("TextLabel", {
			Name = "Desc",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = desc,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextSize = 11.5,
			LayoutOrder = 2,
			Parent = holder,
		})
		win:_bind(descL, "TextColor3", "SubText")
	end
	return holder, titleL, descL
end

-- 検索・表示切替・削除 を全部品に付ける
local function Finish(tab, opts, obj, card)
	local win = tab._window
	local text = tostring(opts.Name or opts.Title or "") .. " " .. tostring(opts.Description or opts.Content or "")
	local item = { card = card, text = string.lower(text), userHidden = false, kind = obj.Type }
	table.insert(tab._items, item)
	obj._card = card
	function obj:SetVisible(b)
		item.userHidden = not b
		win:_applyFilter()
	end
	function obj:Destroy()
		for i, it in ipairs(tab._items) do
			if it == item then
				table.remove(tab._items, i)
				break
			end
		end
		card:Destroy()
		if opts.Flag then
			win.Flags[opts.Flag] = nil
			win.Options[opts.Flag] = nil
		end
	end
	if opts.Flag then
		win.Options[opts.Flag] = obj
	end
	return obj
end

local function SetFlag(win, opts, v)
	if opts.Flag then
		win.Flags[opts.Flag] = v
	end
end

-- Section / Divider / Spacer -------------------------------------------
function Tab:AddSection(opts)
	opts = Opts(opts)
	local win = self._window
	local name = opts.Name or opts.Title or ""
	local row = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = self:_next(),
		Parent = self._page,
	})
	local line = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = row,
	})
	win:_bind(line, "BackgroundColor3", "Stroke")
	local label = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		Text = string.upper(tostring(name)),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = MONO,
		TextSize = 11,
		ZIndex = 2,
		Parent = row,
	}, { Pad(0, 0, 10, 0) })
	win:_bind(label, "TextColor3", "Muted")
	win:_bind(label, "BackgroundColor3", "Background")
	local obj = { Type = "Section" }
	function obj:Set(t)
		label.Text = string.upper(tostring(t))
	end
	return Finish(self, { Name = name }, obj, row)
end

function Tab:AddDivider()
	local win = self._window
	local line = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = self:_next(),
		Parent = self._page,
	})
	win:_bind(line, "BackgroundColor3", "Stroke")
	return Finish(self, {}, { Type = "Divider" }, line)
end

function Tab:AddSpacer(height)
	local sp = New("Frame", {
		Name = "Spacer",
		Size = UDim2.new(1, 0, 0, height or 8),
		BackgroundTransparency = 1,
		LayoutOrder = self:_next(),
		Parent = self._page,
	})
	return Finish(self, {}, { Type = "Spacer" }, sp)
end

-- Label / Paragraph ------------------------------------------------------
function Tab:AddLabel(opts)
	opts = Opts(opts)
	local win = self._window
	local text = opts.Text or opts.Name or ""
	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12.5,
		LayoutOrder = self:_next(),
		Parent = self._page,
	}, { Pad(2, 2, 2, 2) })
	win:_bind(label, "TextColor3", "Muted")
	local obj = { Type = "Label" }
	function obj:Set(t)
		label.Text = tostring(t)
	end
	return Finish(self, { Name = text }, obj, label)
end

function Tab:AddParagraph(opts)
	opts = Opts(opts)
	local win = self._window
	local card = NewCard(self, false)
	local _, title, desc = RowText(win, card, opts.Title or opts.Name or "", opts.Content or opts.Description or "", 0)
	local obj = { Type = "Paragraph" }
	function obj:Set(t, c)
		if t then
			title.Text = t
		end
		if desc and c then
			desc.Text = c
		end
	end
	return Finish(self, opts, obj, card)
end

-- Button(s) --------------------------------------------------------------
local function MakeButton(win, parent, def, order)
	local primary = def.Primary == true
	local label = def.Text or def.Name or "Run"
	local b = New("TextButton", {
		Size = UDim2.new(0, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = primary and win.Theme.Accent or win.Theme.Hover,
		BackgroundTransparency = primary and 0 or 1,
		Text = label,
		Font = SEMI,
		TextSize = 12.5,
		TextColor3 = primary and win.Theme.OnAccent or win.Theme.Text,
		LayoutOrder = order,
		Parent = parent,
	}, { Corner(7), Pad(14, 0, 14, 0) })
	local stroke
	if not primary then
		stroke = Stroke(win.Theme.StrokeStrong, 1)
		stroke.Parent = b
	end
	win:_onTheme(function()
		if b.Parent == nil then
			return
		end
		local t = win.Theme
		if primary then
			b.BackgroundColor3 = t.Accent
			b.TextColor3 = t.OnAccent
		else
			b.BackgroundColor3 = t.Hover
			b.TextColor3 = t.Text
			stroke.Color = t.StrokeStrong
		end
	end)
	b.MouseEnter:Connect(function()
		Tween(b, { BackgroundTransparency = primary and 0.12 or 0 }, 0.12)
	end)
	b.MouseLeave:Connect(function()
		Tween(b, { BackgroundTransparency = primary and 0 or 1 }, 0.12)
	end)
	b.Activated:Connect(function()
		Safe(def.Callback)
	end)
	return b
end

--- 1 行に複数ボタン  AddButtons({ Name = "Config", Buttons = { { Text = "Reset", Callback = f }, { Text = "Apply", Primary = true, Callback = g } } })
function Tab:AddButtons(opts)
	opts = Opts(opts)
	local win = self._window
	local defs = opts.Buttons or {}
	local width = 0
	for _, d in ipairs(defs) do
		width = width + 28 + #(d.Text or d.Name or "Run") * 7.4 + 8
	end
	local card = NewCard(self, false)
	RowText(win, card, opts.Name or "Buttons", opts.Description, math.floor(width) + 24)
	local row = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local obj = { Type = "Buttons", Buttons = {} }
	for i, d in ipairs(defs) do
		obj.Buttons[i] = MakeButton(win, row, d, i)
	end
	function obj:Fire(i)
		local d = defs[i or 1]
		if d then
			Safe(d.Callback)
		end
	end
	return Finish(self, opts, obj, card)
end

--- 単体ボタン  AddButton({ Name = "Reset", Description = "...", Text = "Run", Primary = false, Callback = f })
function Tab:AddButton(opts)
	opts = Opts(opts)
	return self:AddButtons({
		Name = opts.Name or "Button",
		Description = opts.Description,
		Buttons = { { Text = opts.Text or "Run", Primary = opts.Primary, Callback = opts.Callback } },
	})
end

-- Toggle -----------------------------------------------------------------
function Tab:AddToggle(opts)
	opts = Opts(opts)
	local win = self._window
	local card = NewCard(self, true)
	RowText(win, card, opts.Name or "Toggle", opts.Description, 70)
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(38, 22),
		BackgroundColor3 = win.Theme.Track,
		Parent = card,
	}, { Corner(11) })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = win.Theme.SubText,
		Parent = track,
	}, { Corner(8) })

	local obj = { Type = "Toggle", Value = false }
	local function paint(animate)
		local t = win.Theme
		local on = obj.Value
		local d = animate and 0.18 or 0
		Tween(track, { BackgroundColor3 = on and t.Accent or t.Track }, d)
		Tween(knob, {
			Position = on and UDim2.new(0, 19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = on and t.OnAccent or t.SubText,
		}, d)
	end
	win:_onTheme(function()
		paint(true)
	end)
	function obj:Set(v, silent)
		v = v and true or false
		local changed = (self.Value ~= v)
		self.Value = v
		SetFlag(win, opts, v)
		paint(true)
		if changed and not silent then
			Safe(opts.Callback, v)
		end
	end
	function obj:Get()
		return self.Value
	end
	card.Activated:Connect(function()
		obj:Set(not obj.Value)
	end)
	Finish(self, opts, obj, card)
	obj:Set(opts.Default == true, true)
	return obj
end

-- Slider -----------------------------------------------------------------
function Tab:AddSlider(opts)
	opts = Opts(opts)
	local win = self._window
	local min, max = opts.Min or 0, opts.Max or 100
	local inc = opts.Increment or 1
	local decimals = DecimalsOf(inc)

	local card = NewCard(self, false, 58)
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -110, 0, 18),
		Text = opts.Name or "Slider",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = SEMI,
		TextSize = 13,
		Parent = card,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local valL = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(90, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = MONO,
		TextSize = 12,
		Parent = card,
	})
	win:_bind(valL, "TextColor3", "Text")
	local track = New("Frame", {
		Position = UDim2.new(0, 14, 0, 40),
		Size = UDim2.new(1, -28, 0, 4),
		Parent = card,
	}, { Corner(2) })
	win:_bind(track, "BackgroundColor3", "Track")
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), Parent = track }, { Corner(2) })
	win:_bind(fill, "BackgroundColor3", "Accent")
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 2,
		Parent = fill,
	}, { Corner(6) })
	win:_bind(knob, "BackgroundColor3", "Accent")
	local ring = New("UIStroke", {
		Thickness = 3,
		Transparency = 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = knob,
	})
	win:_bind(ring, "Color", "Accent")
	local hit = New("TextButton", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})

	local obj = { Type = "Slider", Value = nil }
	function obj:Set(v, silent)
		v = tonumber(v) or min
		v = math.clamp(math.floor((v - min) / inc + 0.5) * inc + min, min, max)
		v = Round(v, decimals)
		local old = self.Value
		self.Value = v
		local a = (max == min) and 0 or (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		valL.Text = tostring(v) .. (opts.Suffix or "")
		SetFlag(win, opts, v)
		if not silent and v ~= old then
			Safe(opts.Callback, v)
		end
	end
	function obj:Get()
		return self.Value
	end

	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(input)
		if not IsPress(input) then
			return
		end
		self._page.ScrollingEnabled = false
		fromX(input.Position.X)
		Tween(knob, { Size = UDim2.fromOffset(15, 15) }, 0.12)
		win:_beginDrag(function(i)
			fromX(i.Position.X)
		end, function()
			self._page.ScrollingEnabled = true
			Tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.15)
		end)
	end)

	Finish(self, opts, obj, card)
	obj:Set(opts.Default or min, true)
	return obj
end

-- Dropdown ---------------------------------------------------------------
function Tab:AddDropdown(opts)
	opts = Opts(opts)
	local win = self._window
	local multi = opts.Multi == true
	local options = opts.Options or {}
	local placeholder = opts.Placeholder or "Select…"

	local card = NewCard(self, false, 46)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local header = New("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Parent = card,
	})
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -190, 1, 0),
		Text = opts.Name or "Dropdown",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = SEMI,
		TextSize = 13,
		Parent = header,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local pill = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(150, 30),
		Parent = header,
	}, { Corner(7) })
	win:_bind(pill, "BackgroundColor3", "Control")
	local pillStroke = Stroke(win.Theme.StrokeStrong, 1)
	pillStroke.Parent = pill
	win:_bind(pillStroke, "Color", "StrokeStrong")
	local valL = New("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = MED,
		TextSize = 12.5,
		Parent = pill,
	})
	local chevron, arms = MakeChevron(pill)
	for _, a in ipairs(arms) do
		win:_bind(a, "BackgroundColor3", "Muted")
	end

	local listWrap = New("Frame", {
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = card,
	})
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		Parent = listWrap,
	}, { List(3), Pad(14, 0, 14, 10) })
	win:_bind(scroll, "ScrollBarImageColor3", "StrokeStrong")

	local obj = { Type = "Dropdown", Value = multi and {} or nil }
	local selected = {}
	local rows = {}
	local open = false

	local function isSel(o)
		if multi then
			return selected[o] == true
		end
		return obj.Value == o
	end

	local function hasValue()
		if multi then
			return #obj.Value > 0
		end
		return obj.Value ~= nil
	end

	local function updateText()
		if multi then
			local t = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(t, tostring(o))
				end
			end
			valL.Text = (#t == 0) and placeholder or table.concat(t, ", ")
		else
			valL.Text = obj.Value ~= nil and tostring(obj.Value) or placeholder
		end
		valL.TextColor3 = hasValue() and win.Theme.Text or win.Theme.SubText
	end

	local function render()
		for o, r in pairs(rows) do
			local on = isSel(o)
			r.label.TextColor3 = on and win.Theme.Text or win.Theme.Muted
			r.dot.Visible = on
			r.dot.BackgroundColor3 = win.Theme.Accent
			r.btn.BackgroundColor3 = win.Theme.Control
		end
		updateText()
	end
	win:_onTheme(render)

	local function listHeight()
		local n = #options
		if n == 0 then
			return 0
		end
		return math.min(n * 30 + (n - 1) * 3 + 10, 170)
	end

	local function setOpen(state)
		open = state
		Tween(listWrap, { Size = UDim2.new(1, 0, 0, open and listHeight() or 0) }, 0.25, Enum.EasingStyle.Quint)
		Tween(chevron, { Rotation = open and 180 or 0 }, 0.25, Enum.EasingStyle.Quint)
	end

	local function arrayFromSelected()
		local arr = {}
		for _, o in ipairs(options) do
			if selected[o] then
				table.insert(arr, o)
			end
		end
		return arr
	end

	function obj:Set(v, silent)
		if multi then
			selected = {}
			if type(v) == "table" then
				for _, x in ipairs(v) do
					selected[x] = true
				end
			end
			self.Value = arrayFromSelected()
		else
			self.Value = v
		end
		SetFlag(win, opts, self.Value)
		render()
		if not silent then
			Safe(opts.Callback, self.Value)
		end
	end
	function obj:Get()
		return self.Value
	end
	function obj:Open()
		setOpen(true)
	end
	function obj:Close()
		setOpen(false)
	end

	local function buildRows()
		for _, r in pairs(rows) do
			r.btn:Destroy()
		end
		rows = {}
		for i, o in ipairs(options) do
			local btn = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = win.Theme.Control,
				Text = "",
				LayoutOrder = i,
				Parent = scroll,
			}, { Corner(7) })
			local label = New("TextLabel", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -34, 1, 0),
				Text = tostring(o),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Font = MED,
				TextSize = 12.5,
				TextColor3 = win.Theme.Muted,
				Parent = btn,
			})
			local dot = New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = win.Theme.Accent,
				Visible = false,
				Parent = btn,
			}, { Corner(3) })
			rows[o] = { btn = btn, label = label, dot = dot }
			btn.MouseEnter:Connect(function()
				Tween(btn, { BackgroundColor3 = win.Theme.Hover }, 0.1)
			end)
			btn.MouseLeave:Connect(function()
				Tween(btn, { BackgroundColor3 = win.Theme.Control }, 0.1)
			end)
			btn.Activated:Connect(function()
				if multi then
					if selected[o] then
						selected[o] = nil
					else
						selected[o] = true
					end
					obj:Set(arrayFromSelected())
				else
					obj:Set(o)
					setOpen(false)
				end
			end)
		end
	end

	function obj:Refresh(newOptions, keep)
		options = newOptions or {}
		buildRows()
		if keep then
			if multi then
				self:Set(self.Value, true)
			else
				local found = false
				for _, o in ipairs(options) do
					if o == self.Value then
						found = true
					end
				end
				self:Set(found and self.Value or nil, true)
			end
		else
			self:Set(multi and {} or nil, true)
		end
		if open then
			setOpen(true)
		end
	end

	header.Activated:Connect(function()
		setOpen(not open)
	end)

	buildRows()
	Finish(self, opts, obj, card)
	obj:Set(opts.Default, true)
	return obj
end

-- Input ------------------------------------------------------------------
function Tab:AddInput(opts)
	opts = Opts(opts)
	local win = self._window
	local card = NewCard(self, false)
	RowText(win, card, opts.Name or "Input", opts.Description, 184)
	local box = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 30),
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "Type here…",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 12.5,
		Parent = card,
	}, { Corner(7), Pad(10, 0, 10, 0) })
	win:_bind(box, "BackgroundColor3", "Control")
	win:_bind(box, "TextColor3", "Text")
	win:_bind(box, "PlaceholderColor3", "SubText")
	local stroke = Stroke(win.Theme.StrokeStrong, 1)
	stroke.Parent = box
	win:_bind(stroke, "Color", "StrokeStrong")

	local obj = { Type = "Input", Value = box.Text }
	function obj:Set(t, silent)
		t = tostring(t or "")
		box.Text = t
		self.Value = t
		SetFlag(win, opts, t)
		if not silent then
			Safe(opts.Callback, t, false)
		end
	end
	function obj:Get()
		return self.Value
	end
	box.Focused:Connect(function()
		Tween(stroke, { Color = win.Theme.Accent }, 0.15)
	end)
	box.FocusLost:Connect(function(enter)
		Tween(stroke, { Color = win.Theme.StrokeStrong }, 0.15)
		local t = box.Text
		if opts.NumbersOnly then
			t = t:gsub("[^%d%.%-]", "")
			box.Text = t
		end
		obj.Value = t
		SetFlag(win, opts, t)
		Safe(opts.Callback, t, enter)
	end)
	Finish(self, opts, obj, card)
	SetFlag(win, opts, box.Text)
	return obj
end
Tab.AddTextbox = Tab.AddInput

-- Keybind ----------------------------------------------------------------
function Tab:AddKeybind(opts)
	opts = Opts(opts)
	local win = self._window
	local card = NewCard(self, false)
	RowText(win, card, opts.Name or "Keybind", opts.Description, 130)
	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		Font = MONO,
		TextSize = 11.5,
		Parent = card,
	}, { Corner(7), Pad(12, 0, 12, 0) })
	win:_bind(btn, "BackgroundColor3", "Control")
	win:_bind(btn, "TextColor3", "Text")
	local stroke = Stroke(win.Theme.StrokeStrong, 1)
	stroke.Parent = btn
	win:_bind(stroke, "Color", "StrokeStrong")

	local obj = { Type = "Keybind", Value = nil }
	local listening = false
	local mode = opts.Mode or "Press"
	local held = false

	local function resolve(k)
		if type(k) == "string" then
			local ok, e = pcall(function()
				return Enum.KeyCode[k]
			end)
			return ok and e or nil
		end
		return k
	end
	local function label()
		btn.Text = obj.Value and obj.Value.Name or "None"
	end

	function obj:Set(k, silent)
		k = resolve(k)
		self.Value = k
		label()
		SetFlag(win, opts, k)
		if not silent then
			Safe(opts.ChangedCallback, k)
		end
	end
	function obj:Get()
		return self.Value
	end

	local function stopListening()
		listening = false
		Tween(stroke, { Color = win.Theme.StrokeStrong }, 0.15)
		task.defer(function()
			win._capturing = false
		end)
		label()
	end

	btn.Activated:Connect(function()
		listening = true
		win._capturing = true
		btn.Text = "…"
		Tween(stroke, { Color = win.Theme.Accent }, 0.15)
	end)
	local connBegan = win:_connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					stopListening()
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					obj:Set(nil)
					stopListening()
				else
					obj:Set(input.KeyCode)
					stopListening()
				end
			end
			return
		end
		if processed or not obj.Value or input.KeyCode ~= obj.Value then
			return
		end
		if mode == "Hold" then
			Safe(opts.Callback, true)
		elseif mode == "Toggle" then
			held = not held
			Safe(opts.Callback, held)
		else
			Safe(opts.Callback)
		end
	end)
	local connEnded = win:_connect(UserInputService.InputEnded, function(input)
		if mode == "Hold" and obj.Value and input.KeyCode == obj.Value then
			Safe(opts.Callback, false)
		end
	end)

	Finish(self, opts, obj, card)
	local baseDestroy = obj.Destroy
	function obj:Destroy()
		connBegan:Disconnect()
		connEnded:Disconnect()
		baseDestroy(self)
	end
	obj:Set(opts.Default, true)
	return obj
end

-- ColorPicker ------------------------------------------------------------
function Tab:AddColorPicker(opts)
	opts = Opts(opts)
	local win = self._window
	local card = NewCard(self, false, 46)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Parent = card,
	})
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Text = opts.Name or "Color",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = SEMI,
		TextSize = 13,
		Parent = header,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		Parent = header,
	}, { Corner(6) })
	local sws = Stroke(win.Theme.StrokeStrong, 1)
	sws.Parent = swatch
	win:_bind(sws, "Color", "StrokeStrong")

	local panel = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = card,
	})
	local svBox = New("Frame", {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -28, 0, 100),
		Active = true,
		ClipsDescendants = true,
		Parent = panel,
	}, { Corner(7) })
	local whiteL = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = svBox })
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteL })
	local blackL = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Parent = svBox })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackL })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = svBox,
	}, { Corner(6), Stroke(WHITE, 2) })

	local hueBar = New("Frame", {
		Position = UDim2.fromOffset(14, 114),
		Size = UDim2.new(1, -28, 0, 12),
		BackgroundColor3 = WHITE,
		Active = true,
		Parent = panel,
	}, { Corner(6) })
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)))
	end
	kps[7] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
	New("UIGradient", { Color = ColorSequence.new(kps), Parent = hueBar })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(6, 18),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Parent = hueBar,
	}, { Corner(3), Stroke(BLACK, 1.5) })

	local hexBox = New("TextBox", {
		Position = UDim2.fromOffset(14, 136),
		Size = UDim2.fromOffset(110, 28),
		ClearTextOnFocus = false,
		Text = "",
		Font = MONO,
		TextSize = 12,
		Parent = panel,
	}, { Corner(7) })
	win:_bind(hexBox, "BackgroundColor3", "Control")
	win:_bind(hexBox, "TextColor3", "Text")
	local hs = Stroke(win.Theme.StrokeStrong, 1)
	hs.Parent = hexBox
	win:_bind(hs, "Color", "StrokeStrong")

	local h, s, v = 0, 1, 1
	local obj = { Type = "ColorPicker", Value = WHITE }

	local function refresh()
		local c = Color3.fromHSV(h, s, v)
		obj.Value = c
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		swatch.BackgroundColor3 = c
		if not hexBox:IsFocused() then
			hexBox.Text = ToHex(c)
		end
		SetFlag(win, opts, c)
	end

	function obj:Set(c, silent)
		if type(c) == "string" then
			c = FromHex(c)
		end
		if typeof(c) ~= "Color3" then
			return
		end
		h, s, v = c:ToHSV()
		refresh()
		if not silent then
			Safe(opts.Callback, self.Value)
		end
	end
	function obj:Get()
		return self.Value
	end

	local function apply(kind, input)
		if kind == "sv" then
			local p, sz = svBox.AbsolutePosition, svBox.AbsoluteSize
			s = math.clamp((input.Position.X - p.X) / math.max(sz.X, 1), 0, 1)
			v = 1 - math.clamp((input.Position.Y - p.Y) / math.max(sz.Y, 1), 0, 1)
		else
			local p, sz = hueBar.AbsolutePosition, hueBar.AbsoluteSize
			h = math.clamp((input.Position.X - p.X) / math.max(sz.X, 1), 0, 0.999)
		end
		refresh()
		Safe(opts.Callback, obj.Value)
	end
	local function begin(kind)
		return function(input)
			if not IsPress(input) then
				return
			end
			self._page.ScrollingEnabled = false
			apply(kind, input)
			win:_beginDrag(function(i)
				apply(kind, i)
			end, function()
				self._page.ScrollingEnabled = true
			end)
		end
	end
	svBox.InputBegan:Connect(begin("sv"))
	hueBar.InputBegan:Connect(begin("hue"))
	hexBox.FocusLost:Connect(function()
		local c = FromHex(hexBox.Text)
		if c then
			obj:Set(c)
		else
			hexBox.Text = ToHex(obj.Value)
		end
	end)

	local open = false
	header.Activated:Connect(function()
		open = not open
		Tween(panel, { Size = UDim2.new(1, 0, 0, open and 174 or 0) }, 0.28, Enum.EasingStyle.Quint)
	end)

	Finish(self, opts, obj, card)
	obj:Set(opts.Default or WHITE, true)
	return obj
end

return Onyx
