--[[ 
    ONYX UI  v1.0.0  (Stealth / Security Enhanced)
    Roblox 用 UI ライブラリ ― 隠蔽・検知対策カスタム版
]]  

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- ランダムなプレフィックスを生成して一意にする（識別困難化）
local function genRandomString(length)
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local s = ""
	math.randomseed(tick() + math.random(1000, 99999))
	for i = 1, length or 8 do
		local rand = math.random(1, #chars)
		s = s .. chars:sub(rand, rand)
	end
	return s
end

local UI_ID = genRandomString(10)

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
	-- 固有名詞の露出を防ぐため、名前にランダム文字列を付与または無害化
	if props and props.Name then
		props.Name = UI_ID .. "_" .. props.Name
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
		-- 警告ログによる検出リスクを下げるため、あえてログ出力を無効化（コメントアウト）
		-- if not ok then warn("[Onyx] callback error: " .. tostring(err)) end
	end
end

local function Opts(o)
	if type(o) == "string" then
		return { Name = o }
	end
	return o or {}
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function GetTargetParent()
	-- 可能であればCoreGuiへ隠蔽を試みる（保護機能のある環境用）
	local success, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if success and coreGui and (syn or cloneref or gethui) then
		local target = gethui and gethui() or coreGui
		return target
	end
	return Onyx.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
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
		Name = "SysCore_" .. UI_ID,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		Parent = GetTargetParent(),
	})
	local cam = workspace.CurrentCamera
	local vpx = cam and cam.ViewportSize.X or 1280
	New("Frame", {
		Name = "NotifContainer",
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
	local holder = gui:FindFirstChild("NotifContainer")

	local live = {}
	if holder then
		for _, c in ipairs(holder:GetChildren()) do
			if c:IsA("Frame") then
				table.insert(live, c)
			end
		end
		if #live >= 5 then
			live[1]:Destroy()
		end
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
		Text = opts.Title or opts.Name or "System",
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
		Text = "OK",
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

return Onyx
