--[[
	🔥 BlazeUI  v1.0.0  (Client)
	Roblox 用 UI ライブラリ ― クライアント側専用

	  • アニメーション付きウィンドウ (開閉・最小化・ドラッグ・回転グラデ枠)
	  • タブ / セクション / ラベル / 段落 / 区切り線
	  • ボタン / トグル / スライダー / ドロップダウン(複数選択可) / 入力欄 / キーバインド / カラーピッカー
	  • 通知 (Info / Success / Warning / Error)、紙吹雪、イントロ演出
	  • テーマ 6種 + カスタムテーマ、スマホ対応(フローティングボタン)
	  • Flags / Options / 設定の JSON 書き出し・読み込み

	使い方は README.md と examples/Demo.client.lua を見てください。
	License: MIT
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Library = {}
Library.Version = "1.0.0"
Library.Windows = {}
Library.Parent = nil -- 変更したい場合は GUI の親を指定 (既定: PlayerGui)

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local rgb = Color3.fromRGB

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local function MakeTheme(t)
	return {
		Background = t[1],
		Surface = t[2],
		Elevated = t[3],
		Accent = t[4],
		Accent2 = t[5],
		Text = t[6],
		SubText = t[7],
		Stroke = t[8],
		Success = rgb(60, 230, 140),
		Warning = rgb(255, 200, 50),
		Danger = rgb(255, 70, 90),
	}
end

local Themes = {
	Blaze = MakeTheme({ rgb(20, 16, 36), rgb(32, 26, 56), rgb(50, 41, 86), rgb(255, 122, 24), rgb(255, 45, 120), rgb(255, 255, 255), rgb(190, 180, 220), rgb(86, 70, 134) }),
	Neon = MakeTheme({ rgb(8, 12, 28), rgb(16, 22, 48), rgb(28, 38, 76), rgb(0, 229, 255), rgb(170, 70, 255), rgb(255, 255, 255), rgb(160, 180, 220), rgb(50, 70, 130) }),
	Candy = MakeTheme({ rgb(38, 18, 48), rgb(58, 28, 74), rgb(86, 44, 104), rgb(255, 105, 180), rgb(255, 196, 70), rgb(255, 255, 255), rgb(224, 186, 230), rgb(120, 70, 140) }),
	Toxic = MakeTheme({ rgb(8, 20, 14), rgb(14, 34, 24), rgb(24, 56, 40), rgb(130, 255, 60), rgb(0, 215, 165), rgb(255, 255, 255), rgb(170, 220, 190), rgb(40, 96, 66) }),
	Ocean = MakeTheme({ rgb(8, 18, 38), rgb(14, 32, 62), rgb(24, 52, 94), rgb(60, 160, 255), rgb(80, 240, 220), rgb(255, 255, 255), rgb(170, 200, 235), rgb(40, 84, 140) }),
	Light = MakeTheme({ rgb(242, 242, 252), rgb(255, 255, 255), rgb(231, 231, 246), rgb(255, 110, 30), rgb(255, 50, 130), rgb(30, 26, 50), rgb(112, 106, 142), rgb(208, 206, 232) }),
}
Library.Themes = Themes

local function Copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function ResolveTheme(t)
	if type(t) == "table" then
		local out = Copy(Themes[t.Base or "Blaze"] or Themes.Blaze)
		for k, v in pairs(t) do
			if k ~= "Base" then
				out[k] = v
			end
		end
		return out
	end
	return Copy(Themes[t or "Blaze"] or Themes.Blaze)
end

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------
local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function New(class, props, children)
	local inst = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		inst.Font = Enum.Font.GothamMedium
		inst.TextSize = 14
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

local function UICorner(r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function UIPad(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
	})
end

local function UIList(padding)
	return New("UIListLayout", { Padding = UDim.new(0, padding or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function Safe(fn, ...)
	if type(fn) == "function" then
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[BlazeUI] callback error: " .. tostring(err))
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

local function ToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
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

local function AccentSeq(theme, loop)
	if loop then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.Accent),
			ColorSequenceKeypoint.new(0.5, theme.Accent2),
			ColorSequenceKeypoint.new(1, theme.Accent),
		})
	end
	return ColorSequence.new(theme.Accent, theme.Accent2)
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function Ripple(parent, input, color)
	local abs = parent.AbsolutePosition
	local rel = Vector2.new(input.Position.X - abs.X, input.Position.Y - abs.Y)
	local circle = New("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(rel.X, rel.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color or WHITE,
		BackgroundTransparency = 0.6,
		Parent = parent,
	}, { UICorner(999) })
	local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
	Tween(circle, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, 0.6)
	task.delay(0.65, function()
		circle:Destroy()
	end)
end

local function MakeDraggable(handle, target, bounds, conns)
	local dragging, dragInput, dragStart, startAbs, startPos = false, nil, nil, nil, nil
	local moved = false
	handle.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = target.Position
			startAbs = target.AbsolutePosition
				+ Vector2.new(target.AbsoluteSize.X * target.AnchorPoint.X, target.AbsoluteSize.Y * target.AnchorPoint.Y)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if IsMove(input) then
			dragInput = input
		end
	end)
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input == dragInput then
				local delta = input.Position - dragStart
				if delta.Magnitude > 4 then
					moved = true
				end
				local vp = bounds.AbsoluteSize
				local dx = math.clamp(startAbs.X + delta.X, 40, vp.X - 40) - startAbs.X
				local dy = math.clamp(startAbs.Y + delta.Y, 30, vp.Y - 30) - startAbs.Y
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dx, startPos.Y.Scale, startPos.Y.Offset + dy)
			end
		end)
	)
	return function()
		return moved
	end
end

local function GetTargetParent()
	return Library.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
end

----------------------------------------------------------------------
-- Overlay (notifications / confetti)
----------------------------------------------------------------------
local overlay

local function GetOverlay()
	if overlay and overlay.Parent then
		return overlay
	end
	overlay = New("ScreenGui", {
		Name = "BlazeUI_Overlay",
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
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.new(0, math.min(310, vpx * 0.62), 1, -28),
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
--- Library:Notify({ Title = "やったね!", Content = "成功!", Type = "Success", Duration = 4 })
function Library:Notify(opts)
	opts = Opts(opts)
	if opts.Name and not opts.Title then
		opts.Title = opts.Name
	end
	local theme = Library._theme or Themes.Blaze
	local kinds = {
		Info = { theme.Accent, "💡" },
		Success = { theme.Success, "✅" },
		Warning = { theme.Warning, "⚠️" },
		Error = { theme.Danger, "⛔" },
	}
	local kind = kinds[opts.Type or "Info"] or kinds.Info
	local duration = opts.Duration or 4
	local gui = GetOverlay()
	local holder = gui:FindFirstChild("Notifications")

	local wrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local card = New("TextButton", {
		Name = "Card",
		Position = UDim2.new(1.3, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 54),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Surface,
		ClipsDescendants = true,
		Text = "",
		Parent = wrap,
	}, {
		UICorner(12),
		New("UIStroke", { Color = kind[1], Thickness = 1.5, Transparency = 0.15 }),
	})
	New("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = kind[1], Parent = card })
	New("TextLabel", {
		Position = UDim2.fromOffset(16, 11),
		Size = UDim2.fromOffset(26, 26),
		Text = kind[2],
		TextSize = 20,
		Parent = card,
	})
	local textHolder = New("Frame", {
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -58, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { UIList(2), UIPad(0, 11, 0, 13) })
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "BlazeUI",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = theme.Text,
		LayoutOrder = 1,
		Parent = textHolder,
	})
	if opts.Content and opts.Content ~= "" then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
			TextColor3 = theme.SubText,
			LayoutOrder = 2,
			Parent = textHolder,
		})
	end
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = kind[1],
		Parent = card,
	})

	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.5, Enum.EasingStyle.Back)
	Tween(bar, { Size = UDim2.new(0, 0, 0, 3) }, duration, Enum.EasingStyle.Linear)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Tween(card, { Position = UDim2.new(1.3, 0, 0, 0) }, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.4, function()
			wrap:Destroy()
		end)
	end
	card.Activated:Connect(close)
	task.delay(duration, close)
end

--- 紙吹雪
function Library:Confetti(count)
	local gui = GetOverlay()
	local vp = gui.AbsoluteSize
	count = count or 70
	for _ = 1, count do
		local startX = vp.X * (0.35 + math.random() * 0.3)
		local startY = vp.Y * 0.55
		local piece = New("Frame", {
			Size = UDim2.fromOffset(math.random(6, 12), math.random(8, 15)),
			Position = UDim2.fromOffset(startX, startY),
			Rotation = math.random(0, 360),
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1),
			ZIndex = 50,
			Parent = gui,
		})
		local peakX = startX + (math.random() - 0.5) * vp.X * 0.7
		local peakY = vp.Y * (0.12 + math.random() * 0.25)
		local upT = 0.35 + math.random() * 0.25
		Tween(piece, { Position = UDim2.fromOffset(peakX, peakY), Rotation = piece.Rotation + math.random(-200, 200) }, upT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(upT, function()
			local downT = 1.1 + math.random() * 1.1
			Tween(piece, {
				Position = UDim2.fromOffset(peakX + (math.random() - 0.5) * 160, vp.Y + 30),
				Rotation = piece.Rotation + math.random(-400, 400),
				BackgroundTransparency = 0.4,
			}, downT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(downT + 0.05, function()
				piece:Destroy()
			end)
		end)
	end
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

function Window:_gradient(g, loop)
	g.Color = AccentSeq(self.Theme, loop)
	table.insert(self._gradients, { g = g, loop = loop })
	return g
end

function Window:_onTheme(fn)
	table.insert(self._hooks, fn)
end

function Window:SetTheme(theme)
	self.Theme = ResolveTheme(theme)
	Library._theme = self.Theme
	for i = #self._bindings, 1, -1 do
		local b = self._bindings[i]
		if b.inst.Parent == nil then
			table.remove(self._bindings, i)
		else
			Tween(b.inst, { [b.prop] = self.Theme[b.key] }, 0.35)
		end
	end
	for i = #self._gradients, 1, -1 do
		local g = self._gradients[i]
		if g.g.Parent == nil then
			table.remove(self._gradients, i)
		else
			g.g.Color = AccentSeq(self.Theme, g.loop)
		end
	end
	for _, fn in ipairs(self._hooks) do
		Safe(fn)
	end
end

function Window:Notify(opts)
	Library:Notify(opts)
end

function Window:Show()
	if self._destroyed or self._visible then
		return
	end
	self._visible = true
	self._holder.Visible = true
	self._main.GroupTransparency = 1
	self._border.BackgroundTransparency = 1
	self._shadow.ImageTransparency = 1
	self._scale.Scale = 0.8
	Tween(self._scale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
	Tween(self._main, { GroupTransparency = 0 }, 0.3)
	Tween(self._border, { BackgroundTransparency = 0 }, 0.3)
	Tween(self._shadow, { ImageTransparency = 0.45 }, 0.3)
end

function Window:Hide()
	if not self._visible then
		return
	end
	self._visible = false
	Tween(self._scale, { Scale = 0.85 }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(self._main, { GroupTransparency = 1 }, 0.22)
	Tween(self._border, { BackgroundTransparency = 1 }, 0.22)
	Tween(self._shadow, { ImageTransparency = 1 }, 0.22)
	task.delay(0.27, function()
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

function Window:SetMinimized(state)
	self._minimized = state and true or false
	if self._minimized then
		Tween(self._holder, { Size = UDim2.fromOffset(self._w, 52) }, 0.35, Enum.EasingStyle.Back)
		self._minBtn.Text = "▢"
	else
		Tween(self._holder, { Size = UDim2.fromOffset(self._w, self._h) }, 0.4, Enum.EasingStyle.Back)
		self._minBtn.Text = "—"
	end
end

function Window:SelectTab(tab)
	if self._active == tab then
		return
	end
	local old = self._active
	if old then
		old._page.Visible = false
		Tween(old._fill, { BackgroundTransparency = 1 }, 0.2)
		if old._label then
			Tween(old._label, { TextColor3 = self.Theme.SubText }, 0.2)
		end
		old._active = false
	end
	self._active = tab
	tab._active = true
	tab._page.Position = UDim2.fromOffset(0, 18)
	tab._page.Visible = true
	Tween(tab._page, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Quint)
	Tween(tab._fill, { BackgroundTransparency = 0 }, 0.25)
	if tab._label then
		Tween(tab._label, { TextColor3 = WHITE }, 0.2)
	end
end

function Window:AddTab(opts)
	opts = Opts(opts)
	local name = opts.Name or ("Tab " .. (#self.Tabs + 1))
	local icon = opts.Icon or "⭐"
	local tab = setmetatable({}, Tab)
	tab._window = self
	tab._order = 0
	tab.Name = name

	local btn = New("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Tabs + 1,
		Parent = self._tabList,
	}, { UICorner(10) })
	self:_bind(btn, "BackgroundColor3", "Elevated")
	local fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Parent = btn,
	}, { UICorner(10) })
	self:_gradient(New("UIGradient", { Rotation = 20, Parent = fill }))

	local iconObj
	if type(icon) == "string" and icon:sub(1, 11) == "rbxassetid:" then
		iconObj = New("ImageLabel", {
			AnchorPoint = Vector2.new(self._compact and 0.5 or 0, 0.5),
			Position = self._compact and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			Image = icon,
			Parent = btn,
		})
	else
		iconObj = New("TextLabel", {
			AnchorPoint = Vector2.new(self._compact and 0.5 or 0, 0.5),
			Position = self._compact and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Text = tostring(icon),
			TextSize = 20,
			Parent = btn,
		})
	end
	tab._icon = iconObj

	if not self._compact then
		local label = New("TextLabel", {
			Position = UDim2.new(0, 42, 0, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = self.Theme.SubText,
			Parent = btn,
		})
		tab._label = label
		self:_onTheme(function()
			label.TextColor3 = tab._active and WHITE or self.Theme.SubText
		end)
	end

	local page = New("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	}, { UIList(8), UIPad(12, 12, 14, 12) })
	self:_bind(page, "ScrollBarImageColor3", "Accent")

	tab._btn, tab._fill, tab._page = btn, fill, page

	btn.MouseEnter:Connect(function()
		if not tab._active then
			Tween(btn, { BackgroundTransparency = 0.5 }, 0.15)
		end
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, { BackgroundTransparency = 1 }, 0.15)
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
	for i, w in ipairs(Library.Windows) do
		if w == self then
			table.remove(Library.Windows, i)
			break
		end
	end
end

function Library:DestroyAll()
	for i = #Library.Windows, 1, -1 do
		Library.Windows[i]:Destroy()
	end
end

----------------------------------------------------------------------
-- CreateWindow
----------------------------------------------------------------------
--[[
	Library:CreateWindow({
		Title = "My Hub", Subtitle = "v1.0", Icon = "🔥",
		Theme = "Blaze" | "Neon" | "Candy" | "Toxic" | "Ocean" | "Light" | { 自作テーマ },
		Size = UDim2.fromOffset(620, 410),
		ToggleKey = Enum.KeyCode.RightShift,
		Intro = true,            -- 起動演出
		FloatingButton = nil,    -- nil=タッチ端末で自動表示 / true / false
	})
]]
function Library:CreateWindow(config)
	config = Opts(config)
	local self = setmetatable({}, Window)
	self.Title = config.Title or "BlazeUI"
	self.Subtitle = config.Subtitle or ""
	self.Icon = config.Icon or "🔥"
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
	self.Theme = ResolveTheme(config.Theme)
	Library._theme = self.Theme
	self.Flags = {}
	self.Options = {}
	self.Tabs = {}
	self._bindings, self._gradients, self._hooks, self._conns = {}, {}, {}, {}
	self._visible, self._minimized, self._destroyed = false, false, false

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w, h = 620, 410
	if config.Size then
		w, h = config.Size.X.Offset, config.Size.Y.Offset
	end
	w = math.min(w, vp.X - 24)
	h = math.min(h, vp.Y - 24)
	self._w, self._h = w, h
	self._compact = w < 540
	local sideW = self._compact and 58 or 164

	local gui = New("ScreenGui", {
		Name = "BlazeUI_" .. self.Title,
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
	local scale = New("UIScale", { Scale = 0.8, Parent = holder })
	local shadow = New("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 64, 1, 64),
		Image = "rbxassetid://6014261993",
		ImageColor3 = BLACK,
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
		Parent = holder,
	})
	local border = New("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Parent = holder,
	}, { UICorner(16) })
	local borderGrad = self:_gradient(New("UIGradient", { Parent = border }), true)
	local main = New("CanvasGroup", {
		Name = "Main",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		Parent = holder,
	}, { UICorner(14) })
	self:_bind(main, "BackgroundColor3", "Background")

	self._holder, self._scale, self._shadow, self._border, self._main = holder, scale, shadow, border, main

	-- 枠のグラデをくるくる回す
	self:_connect(RunService.RenderStepped, function(dt)
		if self._visible then
			borderGrad.Rotation = (borderGrad.Rotation + dt * 90) % 360
		end
	end)

	-- Top bar
	local top = New("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 48), Active = true, Parent = main })
	self:_bind(top, "BackgroundColor3", "Surface")
	local topLine = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = WHITE,
		Parent = top,
	})
	self:_gradient(New("UIGradient", { Parent = topLine }))

	New("TextLabel", {
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.fromOffset(30, 30),
		Text = tostring(self.Icon),
		TextSize = 24,
		Parent = top,
	})
	local hasSub = self.Subtitle ~= ""
	local titleL = New("TextLabel", {
		Position = UDim2.fromOffset(48, hasSub and 5 or 0),
		Size = UDim2.new(1, -140, 0, hasSub and 22 or 46),
		Text = self.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		Parent = top,
	})
	self:_bind(titleL, "TextColor3", "Text")
	if hasSub then
		local subL = New("TextLabel", {
			Position = UDim2.fromOffset(48, 26),
			Size = UDim2.new(1, -140, 0, 16),
			Text = self.Subtitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = 11,
			Parent = top,
		})
		self:_bind(subL, "TextColor3", "SubText")
	end

	local function topButton(text, xOff)
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, -1),
			Size = UDim2.fromOffset(32, 32),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			Parent = top,
		}, { UICorner(9) })
		self:_bind(b, "BackgroundColor3", "Elevated")
		self:_bind(b, "TextColor3", "Text")
		return b
	end
	local closeBtn = topButton("✕", -10)
	local minBtn = topButton("—", -48)
	self._minBtn = minBtn
	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, { BackgroundColor3 = self.Theme.Danger }, 0.15)
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, { BackgroundColor3 = self.Theme.Elevated }, 0.15)
	end)
	minBtn.MouseEnter:Connect(function()
		Tween(minBtn, { BackgroundColor3 = self.Theme.Accent }, 0.15)
	end)
	minBtn.MouseLeave:Connect(function()
		Tween(minBtn, { BackgroundColor3 = self.Theme.Elevated }, 0.15)
	end)
	closeBtn.Activated:Connect(function()
		self:Hide()
		if not self._hintShown and not UserInputService.TouchEnabled then
			self._hintShown = true
			Library:Notify({
				Title = "ウィンドウを閉じました",
				Content = self.ToggleKey.Name .. " でもう一度開けます",
				Type = "Info",
			})
		end
	end)
	minBtn.Activated:Connect(function()
		self:SetMinimized(not self._minimized)
	end)

	MakeDraggable(top, holder, gui, self._conns)

	-- Body
	local body = New("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = main,
	})
	local sidebar = New("Frame", { Name = "Sidebar", Size = UDim2.new(0, sideW, 1, 0), Parent = body })
	self:_bind(sidebar, "BackgroundColor3", "Surface")
	local sideLine = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})
	self:_bind(sideLine, "BackgroundColor3", "Stroke")
	local tabList = New("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, -1, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = sidebar,
	}, { UIList(6), UIPad(8, 10, 8, 10) })
	local content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(sideW, 0),
		Size = UDim2.new(1, -sideW, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})
	self._body, self._tabList, self._content = body, tabList, content

	-- Toggle key
	self:_connect(UserInputService.InputBegan, function(input, gp)
		if gp or self._destroyed then
			return
		end
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	-- Floating button (mobile)
	if config.FloatingButton == true or (config.FloatingButton == nil and UserInputService.TouchEnabled) then
		local fb = New("TextButton", {
			Name = "FloatingButton",
			Size = UDim2.fromOffset(54, 54),
			Position = UDim2.new(0, 14, 0.5, -27),
			BackgroundColor3 = WHITE,
			Text = "",
			Parent = gui,
		}, { UICorner(27), New("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.5 }) })
		self:_gradient(New("UIGradient", { Rotation = 45, Parent = fb }))
		New("TextLabel", { Size = UDim2.fromScale(1, 1), Text = tostring(self.Icon), TextSize = 28, Parent = fb })
		local dragged = MakeDraggable(fb, fb, gui, self._conns)
		fb.Activated:Connect(function()
			if not dragged() then
				self:Toggle()
			end
		end)
		self._floating = fb
	end

	table.insert(Library.Windows, self)

	-- Intro splash → Show
	if config.Intro == false then
		self:Show()
	else
		task.spawn(function()
			local splash = New("Frame", {
				Name = "Intro",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(300, 140),
				Parent = gui,
			}, { UICorner(20) })
			self:_bind(splash, "BackgroundColor3", "Background")
			local sScale = New("UIScale", { Scale = 0.5, Parent = splash })
			local stroke = New("UIStroke", { Thickness = 3, Color = WHITE, Parent = splash })
			local sg = self:_gradient(New("UIGradient", { Parent = stroke }), true)
			New("TextLabel", {
				Position = UDim2.fromOffset(0, 16),
				Size = UDim2.new(1, 0, 0, 36),
				Text = tostring(self.Icon),
				TextSize = 32,
				Parent = splash,
			})
			local t1 = New("TextLabel", {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 30),
				Text = self.Title,
				Font = Enum.Font.GothamBlack,
				TextSize = 24,
				Parent = splash,
			})
			self:_bind(t1, "TextColor3", "Text")
			local barBg = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 104),
				Size = UDim2.new(1, -60, 0, 8),
				Parent = splash,
			}, { UICorner(4) })
			self:_bind(barBg, "BackgroundColor3", "Elevated")
			local barFill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = barBg }, { UICorner(4) })
			self:_gradient(New("UIGradient", { Parent = barFill }))

			local spin = RunService.RenderStepped:Connect(function(dt)
				sg.Rotation = (sg.Rotation + dt * 240) % 360
			end)
			Tween(sScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
			task.wait(0.25)
			Tween(barFill, { Size = UDim2.fromScale(1, 1) }, 1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			task.wait(1.15)
			Tween(sScale, { Scale = 1.25 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			Tween(splash, { BackgroundTransparency = 1 }, 0.25)
			stroke.Enabled = false
			for _, d in ipairs(splash:GetDescendants()) do
				if d:IsA("TextLabel") then
					Tween(d, { TextTransparency = 1 }, 0.25)
				elseif d:IsA("Frame") then
					Tween(d, { BackgroundTransparency = 1 }, 0.25)
				end
			end
			task.wait(0.3)
			spin:Disconnect()
			splash:Destroy()
			if not self._destroyed then
				self:Show()
			end
		end)
	end

	return self
end

Library.new = Library.CreateWindow

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

local function MakeCard(tab, clickable, minH)
	local win = tab._window
	local props = {
		Name = "Element",
		Size = UDim2.new(1, 0, 0, minH or 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		LayoutOrder = tab:_next(),
		Parent = tab._page,
	}
	if clickable then
		props.Text = ""
	end
	local stroke = New("UIStroke", { Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local card = New(clickable and "TextButton" or "Frame", props, { UICorner(10), stroke })
	win:_bind(card, "BackgroundColor3", "Surface")
	win:_bind(stroke, "Color", "Stroke")
	if clickable then
		card.MouseEnter:Connect(function()
			Tween(card, { BackgroundColor3 = win.Theme.Elevated }, 0.15)
		end)
		card.MouseLeave:Connect(function()
			Tween(card, { BackgroundColor3 = win.Theme.Surface }, 0.15)
		end)
		card.InputBegan:Connect(function(input)
			if IsPress(input) then
				Ripple(card, input, win.Theme.Accent)
			end
		end)
	end
	return card
end

local function MakeText(win, parent, name, desc, rightPad)
	local holder = New("Frame", {
		Name = "Text",
		Size = UDim2.new(1, -(rightPad or 0), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIList(2), UIPad(12, 13, 6, 13) })
	local title = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = name or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		LayoutOrder = 1,
		Parent = holder,
	})
	win:_bind(title, "TextColor3", "Text")
	local descL
	if desc and desc ~= "" then
		descL = New("TextLabel", {
			Name = "Desc",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = desc,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
			LayoutOrder = 2,
			Parent = holder,
		})
		win:_bind(descL, "TextColor3", "SubText")
	end
	return holder, title, descL
end

local function Finish(win, opts, obj, card)
	obj._card = card
	function obj:SetVisible(b)
		card.Visible = b and true or false
	end
	function obj:Destroy()
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

-- Section ---------------------------------------------------------------
function Tab:AddSection(name)
	local win = self._window
	name = type(name) == "table" and name.Name or name
	local row = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = self:_next(),
		Parent = self._page,
	})
	local label = New("TextLabel", {
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -4, 0, 24),
		Text = string.upper(tostring(name or "")),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		Parent = row,
	})
	win:_bind(label, "TextColor3", "Accent")
	local line = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = WHITE,
		Parent = row,
	})
	local g = New("UIGradient", { Parent = line })
	g.Transparency = NumberSequence.new(0, 1)
	win:_gradient(g)
	return { _card = row, SetVisible = function(_, b) row.Visible = b end }
end

function Tab:AddDivider()
	local win = self._window
	local line = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundTransparency = 0.4,
		LayoutOrder = self:_next(),
		Parent = self._page,
	})
	win:_bind(line, "BackgroundColor3", "Stroke")
	return { _card = line }
end

function Tab:AddSpacer(height)
	New("Frame", { Size = UDim2.new(1, 0, 0, height or 8), BackgroundTransparency = 1, LayoutOrder = self:_next(), Parent = self._page })
end

-- Label / Paragraph -------------------------------------------------------
function Tab:AddLabel(opts)
	opts = Opts(opts)
	local win = self._window
	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Text or opts.Name or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		LayoutOrder = self:_next(),
		Parent = self._page,
	}, { UIPad(4, 0, 4, 0) })
	win:_bind(label, "TextColor3", "SubText")
	local obj = { Type = "Label", _card = label }
	function obj:Set(text)
		label.Text = text
	end
	function obj:SetVisible(b)
		label.Visible = b
	end
	function obj:Destroy()
		label:Destroy()
	end
	return obj
end

function Tab:AddParagraph(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, false, 44)
	local _, title, desc = MakeText(win, card, opts.Title or opts.Name or "", opts.Content or opts.Description or "", 0)
	local obj = { Type = "Paragraph" }
	function obj:Set(t, c)
		if t then
			title.Text = t
		end
		if desc and c then
			desc.Text = c
		end
	end
	return Finish(win, opts, obj, card)
end

-- Button -----------------------------------------------------------------
function Tab:AddButton(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, true)
	MakeText(win, card, opts.Name or "Button", opts.Description, 64)
	local pill = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 26),
		BackgroundColor3 = WHITE,
		Parent = card,
	}, { UICorner(8) })
	win:_gradient(New("UIGradient", { Rotation = 20, Parent = pill }))
	New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = opts.Icon or "▶",
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		Parent = pill,
	})
	local obj = { Type = "Button" }
	function obj:Fire()
		Safe(opts.Callback)
	end
	card.Activated:Connect(function()
		Tween(pill, { Size = UDim2.fromOffset(32, 22) }, 0.08)
		task.delay(0.08, function()
			Tween(pill, { Size = UDim2.fromOffset(40, 26) }, 0.35, Enum.EasingStyle.Back)
		end)
		Safe(opts.Callback)
	end)
	return Finish(win, opts, obj, card)
end

-- Toggle -----------------------------------------------------------------
function Tab:AddToggle(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, true)
	MakeText(win, card, opts.Name or "Toggle", opts.Description, 68)
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(46, 26),
		Parent = card,
	}, { UICorner(13) })
	win:_bind(track, "BackgroundColor3", "Elevated")
	local fill = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Parent = track,
	}, { UICorner(13) })
	win:_gradient(New("UIGradient", { Parent = fill }))
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = track,
	}, { UICorner(10) })

	local obj = { Type = "Toggle", Value = false }
	function obj:Set(v, silent)
		v = v and true or false
		local changed = (self.Value ~= v)
		self.Value = v
		SetFlag(win, opts, v)
		Tween(fill, { BackgroundTransparency = v and 0 or 1 }, 0.2)
		Tween(knob, { Position = v and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.35, Enum.EasingStyle.Back)
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
	Finish(win, opts, obj, card)
	obj:Set(opts.Default == true, true)
	return obj
end

-- Slider -----------------------------------------------------------------
function Tab:AddSlider(opts)
	opts = Opts(opts)
	local win = self._window
	local min, max = opts.Min or 0, opts.Max or 100
	local inc = opts.Increment or 1
	local s = tostring(inc)
	local dot = s:find("%.")
	local decimals = dot and (#s - dot) or 0

	local card = MakeCard(self, false, 60)
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.new(1, -96, 0, 18),
		Text = opts.Name or "Slider",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = card,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local valL = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(80, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		Parent = card,
	})
	win:_bind(valL, "TextColor3", "Accent")
	local track = New("Frame", {
		Position = UDim2.new(0, 12, 0, 40),
		Size = UDim2.new(1, -24, 0, 8),
		Parent = card,
	}, { UICorner(4) })
	win:_bind(track, "BackgroundColor3", "Elevated")
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track }, { UICorner(4) })
	win:_gradient(New("UIGradient", { Parent = fill }))
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = fill,
	}, { UICorner(8), New("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.7 }) })
	local hit = New("TextButton", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 32),
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

	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			self._page.ScrollingEnabled = false
			fromX(input.Position.X)
			Tween(knob, { Size = UDim2.fromOffset(21, 21) }, 0.15, Enum.EasingStyle.Back)
		end
	end)
	win:_connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			fromX(input.Position.X)
		end
	end)
	win:_connect(UserInputService.InputEnded, function(input)
		if dragging and IsPress(input) then
			dragging = false
			self._page.ScrollingEnabled = true
			Tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.2, Enum.EasingStyle.Back)
		end
	end)

	Finish(win, opts, obj, card)
	obj:Set(opts.Default or min, true)
	return obj
end

-- Dropdown ---------------------------------------------------------------
function Tab:AddDropdown(opts)
	opts = Opts(opts)
	local win = self._window
	local multi = opts.Multi == true
	local options = opts.Options or {}
	local placeholder = opts.Placeholder or "選択してね"

	local card = MakeCard(self, false, 44)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local header = New("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Parent = card,
	})
	header.InputBegan:Connect(function(input)
		if IsPress(input) then
			Ripple(header, input, win.Theme.Accent)
		end
	end)
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
		Text = opts.Name or "Dropdown",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = header,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local valL = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -34, 0.5, 0),
		Size = UDim2.new(0.5, -46, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 13,
		Parent = header,
	})
	win:_bind(valL, "TextColor3", "SubText")
	local arrow = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		Text = "▼",
		TextSize = 12,
		Parent = header,
	})
	win:_bind(arrow, "TextColor3", "Accent")

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
		ScrollBarThickness = 3,
		Parent = listWrap,
	}, { UIList(2), UIPad(8, 0, 10, 8) })
	win:_bind(scroll, "ScrollBarImageColor3", "Accent")

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
	end

	local function render()
		for o, r in pairs(rows) do
			local on = isSel(o)
			Tween(r.label, { TextColor3 = on and win.Theme.Accent or win.Theme.Text }, 0.15)
			r.check.Visible = on
			r.btn.BackgroundColor3 = win.Theme.Elevated
		end
	end
	win:_onTheme(render)

	local function contentHeight()
		local n = #options
		return math.min(n * 32 + math.max(n - 1, 0) * 2 + 8, 172)
	end

	local function setOpen(state)
		open = state
		Tween(listWrap, { Size = UDim2.new(1, 0, 0, open and contentHeight() or 0) }, 0.3, Enum.EasingStyle.Quint)
		Tween(arrow, { Rotation = open and 180 or 0 }, 0.3, Enum.EasingStyle.Back)
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
		updateText()
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
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = win.Theme.Elevated,
				Text = "",
				LayoutOrder = i,
				Parent = scroll,
			}, { UICorner(8) })
			local label = New("TextLabel", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -40, 1, 0),
				Text = tostring(o),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = win.Theme.Text,
				Parent = btn,
			})
			local check = New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				Text = "✓",
				Font = Enum.Font.GothamBlack,
				TextSize = 15,
				TextColor3 = win.Theme.Accent,
				Visible = false,
				Parent = btn,
			})
			rows[o] = { btn = btn, label = label, check = check }
			btn.MouseEnter:Connect(function()
				Tween(btn, { BackgroundColor3 = win.Theme.Stroke }, 0.12)
			end)
			btn.MouseLeave:Connect(function()
				Tween(btn, { BackgroundColor3 = win.Theme.Elevated }, 0.12)
			end)
			btn.Activated:Connect(function()
				if multi then
					selected[o] = not selected[o] or nil
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
	Finish(win, opts, obj, card)
	obj:Set(opts.Default, true)
	return obj
end

-- Input ------------------------------------------------------------------
function Tab:AddInput(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, false)
	MakeText(win, card, opts.Name or "Input", opts.Description, 172)
	local box = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 28),
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "入力してね…",
		ClearTextOnFocus = false,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	}, { UICorner(8), UIPad(8, 0, 8, 0) })
	win:_bind(box, "BackgroundColor3", "Elevated")
	win:_bind(box, "TextColor3", "Text")
	win:_bind(box, "PlaceholderColor3", "SubText")
	local stroke = New("UIStroke", { Thickness = 1.5, Transparency = 1, Parent = box })
	win:_bind(stroke, "Color", "Accent")

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
		Tween(stroke, { Transparency = 0 }, 0.15)
	end)
	box.FocusLost:Connect(function(enter)
		Tween(stroke, { Transparency = 1 }, 0.15)
		local t = box.Text
		if opts.NumbersOnly then
			t = t:gsub("[^%d%.%-]", "")
			box.Text = t
		end
		obj.Value = t
		SetFlag(win, opts, t)
		Safe(opts.Callback, t, enter)
	end)
	Finish(win, opts, obj, card)
	SetFlag(win, opts, box.Text)
	return obj
end
Tab.AddTextbox = Tab.AddInput

-- Keybind ----------------------------------------------------------------
function Tab:AddKeybind(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, false)
	MakeText(win, card, opts.Name or "Keybind", opts.Description, 112)
	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(88, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = "",
		Parent = card,
	}, { UICorner(8) })
	win:_bind(btn, "BackgroundColor3", "Elevated")
	win:_bind(btn, "TextColor3", "Accent")

	local obj = { Type = "Keybind", Value = nil }
	local listening = false
	local mode = opts.Mode or "Press"

	local function resolve(k)
		if type(k) == "string" then
			local ok, e = pcall(function()
				return Enum.KeyCode[k]
			end)
			return ok and e or nil
		end
		return k
	end

	function obj:Set(k, silent)
		k = resolve(k)
		self.Value = k
		btn.Text = k and k.Name or "None"
		SetFlag(win, opts, k)
		if not silent then
			Safe(opts.ChangedCallback, k)
		end
	end
	function obj:Get()
		return self.Value
	end

	btn.Activated:Connect(function()
		listening = true
		btn.Text = "…"
	end)
	win:_connect(UserInputService.InputBegan, function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode == Enum.KeyCode.Escape then
					btn.Text = obj.Value and obj.Value.Name or "None"
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					obj:Set(nil)
				else
					obj:Set(input.KeyCode)
				end
			end
			return
		end
		if gp then
			return
		end
		if obj.Value and input.KeyCode == obj.Value then
			if mode == "Hold" then
				Safe(opts.Callback, true)
			else
				Safe(opts.Callback)
			end
		end
	end)
	win:_connect(UserInputService.InputEnded, function(input)
		if mode == "Hold" and obj.Value and input.KeyCode == obj.Value then
			Safe(opts.Callback, false)
		end
	end)

	Finish(win, opts, obj, card)
	obj:Set(opts.Default, true)
	return obj
end

-- ColorPicker --------------------------------------------------------------
function Tab:AddColorPicker(opts)
	opts = Opts(opts)
	local win = self._window
	local card = MakeCard(self, false, 44)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Parent = card,
	})
	header.InputBegan:Connect(function(input)
		if IsPress(input) then
			Ripple(header, input, win.Theme.Accent)
		end
	end)
	local nameL = New("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = opts.Name or "Color",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = header,
	})
	win:_bind(nameL, "TextColor3", "Text")
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		Parent = header,
	}, { UICorner(7), New("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.6 }) })

	local panel = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = card,
	})
	local svBox = New("Frame", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 100),
		Active = true,
		ClipsDescendants = true,
		Parent = panel,
	}, { UICorner(8) })
	local whiteL = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = svBox })
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteL })
	local blackL = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Parent = svBox })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackL })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Parent = svBox,
	}, { UICorner(7), New("UIStroke", { Color = BLACK, Thickness = 1.5 }) })

	local hueBar = New("Frame", {
		Position = UDim2.fromOffset(12, 116),
		Size = UDim2.new(1, -24, 0, 14),
		BackgroundColor3 = WHITE,
		Active = true,
		Parent = panel,
	}, { UICorner(7) })
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)))
	end
	kps[7] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
	New("UIGradient", { Color = ColorSequence.new(kps), Parent = hueBar })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(6, 20),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Parent = hueBar,
	}, { UICorner(3), New("UIStroke", { Color = BLACK, Thickness = 1.5 }) })

	local hexBox = New("TextBox", {
		Position = UDim2.fromOffset(12, 140),
		Size = UDim2.fromOffset(110, 26),
		ClearTextOnFocus = false,
		Text = "",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		Parent = panel,
	}, { UICorner(7) })
	win:_bind(hexBox, "BackgroundColor3", "Elevated")
	win:_bind(hexBox, "TextColor3", "Text")

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
		if typeof(c) == "string" then
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

	local drag = nil
	local function apply(input)
		if drag == "sv" then
			local p, sz = svBox.AbsolutePosition, svBox.AbsoluteSize
			s = math.clamp((input.Position.X - p.X) / math.max(sz.X, 1), 0, 1)
			v = 1 - math.clamp((input.Position.Y - p.Y) / math.max(sz.Y, 1), 0, 1)
		elseif drag == "hue" then
			local p, sz = hueBar.AbsolutePosition, hueBar.AbsoluteSize
			h = math.clamp((input.Position.X - p.X) / math.max(sz.X, 1), 0, 0.999)
		else
			return
		end
		refresh()
		Safe(opts.Callback, obj.Value)
	end
	local function begin(kind)
		return function(input)
			if IsPress(input) then
				drag = kind
				self._page.ScrollingEnabled = false
				apply(input)
			end
		end
	end
	svBox.InputBegan:Connect(begin("sv"))
	hueBar.InputBegan:Connect(begin("hue"))
	win:_connect(UserInputService.InputChanged, function(input)
		if drag and IsMove(input) then
			apply(input)
		end
	end)
	win:_connect(UserInputService.InputEnded, function(input)
		if drag and IsPress(input) then
			drag = nil
			self._page.ScrollingEnabled = true
		end
	end)
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
		Tween(panel, { Size = UDim2.new(1, 0, 0, open and 176 or 0) }, 0.35, Enum.EasingStyle.Quint)
	end)

	Finish(win, opts, obj, card)
	obj:Set(opts.Default or rgb(255, 122, 24), true)
	return obj
end

return Library
