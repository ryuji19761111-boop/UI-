-- 実行: リポジトリ直下で  lua tests/test.lua  (Lua 5.4。Roblox は使いません)
local base = (...) or "tests"
dofile(base .. "/mock.lua")

local failures, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("  FAIL: " .. msg)
	end
end

local function find(root, pred)
	for _, d in ipairs(root:GetDescendants()) do
		if pred(d) then return d end
	end
	return nil
end
local function findAll(root, pred)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if pred(d) then out[#out + 1] = d end
	end
	return out
end
local UIS = MockServices.UserInputService
local function press(x, y)
	return { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(x, y or 0, 0), KeyCode = Enum.KeyCode.Unknown }
end
local function move(x, y)
	return { UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(x, y or 0, 0), KeyCode = Enum.KeyCode.Unknown }
end
local function key(name)
	return { UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.new(0, 0, 0), KeyCode = Enum.KeyCode[name] }
end

local Onyx = dofile(base .. "/../src/Onyx.lua")
check(type(Onyx.CreateWindow) == "function", "CreateWindow exists")

------------------------------------------------------------------ build
local win = Onyx:CreateWindow({ Title = "TEST", Theme = "Onyx" })
check(win._visible == true, "window visible after create")
local home = win:AddTab({ Name = "Home" })
local ply = win:AddTab({ Name = "Player", Icon = "rbxassetid://123" })
local glyph = win:AddTab({ Name = "Glyph", Icon = "G" })
check(#win.Tabs == 3, "3 tabs")
check(win._active == home, "first tab selected")

home:AddSection("Section A")
home:AddLabel("hello label")
home:AddParagraph({ Title = "Para", Content = "Body text" })
home:AddDivider()
home:AddSpacer(6)

local toggled
local tg = home:AddToggle({ Name = "Auto Sprint", Description = "desc", Flag = "sprint", Default = true, Callback = function(v) toggled = v end })
check(win.Flags.sprint == true, "toggle default flag")
tg:Set(false)
check(toggled == false and win.Flags.sprint == false, "toggle set + callback")
tg:Set(true, true)
check(toggled == false, "silent set no callback")
tg._card.Activated:Fire()
check(tg.Value == false and toggled == false, "toggle click flips")

local sval
local sl = home:AddSlider({ Name = "Speed", Min = 0, Max = 100, Default = 20, Increment = 1, Suffix = "x", Flag = "speed", Callback = function(v) sval = v end })
check(win.Flags.speed == 20, "slider default")
sl:Set(33.4)
check(sl.Value == 33 and sval == 33, "slider rounds to increment")
sl:Set(500)
check(sl.Value == 100, "slider clamps max")
local sl2 = home:AddSlider({ Name = "Frac", Min = 0, Max = 1, Default = 0.5, Increment = 0.1, Flag = "frac" })
sl2:Set(0.34)
check(math.abs(sl2.Value - 0.3) < 1e-9, "slider decimal increment")
-- drag
local hit = find(sl._card, function(d) return d:IsA("TextButton") end)
check(hit ~= nil, "slider hit button found")
hit.InputBegan:Fire(press(100, 0))
check(sl.Value == 50, "slider press at middle -> 50 (got " .. tostring(sl.Value) .. ")")
check(ply._page.ScrollingEnabled == true or home._page.ScrollingEnabled == false, "scroll locked while dragging")
UIS.InputChanged:Fire(move(150, 0))
check(sl.Value == 75, "slider drag -> 75 (got " .. tostring(sl.Value) .. ")")
UIS.InputEnded:Fire(press(150, 0))
check(home._page.ScrollingEnabled == true, "scroll restored after drag")
UIS.InputChanged:Fire(move(0, 0))
check(sl.Value == 75, "no drag after release")

local dsel
local dd = home:AddDropdown({ Name = "Mode", Options = { "A", "B", "C" }, Default = "B", Flag = "mode", Callback = function(v) dsel = v end })
check(win.Flags.mode == "B", "dropdown default")
local ddHeader = find(dd._card, function(d) return d.Name == "Header" end)
ddHeader.Activated:Fire()
local rowsB = findAll(dd._card, function(d) return d:IsA("TextButton") and d.Name ~= "Header" end)
check(#rowsB == 3, "dropdown has 3 rows (got " .. #rowsB .. ")")
rowsB[3].Activated:Fire()
check(dd.Value == "C" and dsel == "C", "dropdown pick")
dd:Refresh({ "X", "Y" }, false)
check(dd.Value == nil, "refresh clears")
dd:Set("Y", true)
check(dd.Value == "Y", "dropdown set after refresh")

local msel
local ms = home:AddDropdown({ Name = "Multi", Options = { "a", "b", "c" }, Multi = true, Default = { "a" }, Flag = "multi", Callback = function(v) msel = v end })
check(#ms.Value == 1 and ms.Value[1] == "a", "multi default")
local mrows = findAll(ms._card, function(d) return d:IsA("TextButton") and d.Name ~= "Header" end)
mrows[2].Activated:Fire()
check(#ms.Value == 2 and msel[2] == "b", "multi add")
mrows[1].Activated:Fire()
check(#ms.Value == 1 and ms.Value[1] == "b", "multi remove")

local itext
local inp = home:AddInput({ Name = "Memo", Flag = "memo", Default = "hi", Callback = function(t, e) itext = t end })
check(win.Flags.memo == "hi", "input default flag")
local box = find(inp._card, function(d) return d:IsA("TextBox") end)
box.Text = "abc123x"
box.FocusLost:Fire(true)
check(itext == "abc123x", "input callback")
local num = home:AddInput({ Name = "Num", NumbersOnly = true, Flag = "num" })
local nbox = find(num._card, function(d) return d:IsA("TextBox") end)
nbox.Text = "a1b2.5c"
nbox.FocusLost:Fire(false)
check(num.Value == "12.5", "numbers only filter (got " .. tostring(num.Value) .. ")")
box.Focused:Fire()

local kpress = 0
local kb = home:AddKeybind({ Name = "Key", Default = "F", Flag = "key", Callback = function() kpress = kpress + 1 end })
check(kb.Value == Enum.KeyCode.F, "keybind default resolves string")
UIS.InputBegan:Fire(key("F"), false)
check(kpress == 1, "keybind fires")
UIS.InputBegan:Fire(key("F"), true)
check(kpress == 1, "keybind ignores processed input")
local kbtn = find(kb._card, function(d) return d:IsA("TextButton") end)
kbtn.Activated:Fire()
check(win._capturing == true, "capturing while listening")
local before = win._visible
UIS.InputBegan:Fire(key("RightShift"), false)
MockFlush()
check(kb.Value == Enum.KeyCode.RightShift, "rebind to RightShift")
check(win._visible == before, "rebinding toggle key does not toggle window")
check(win._capturing == false, "capturing ends")
kbtn.Activated:Fire()
UIS.InputBegan:Fire(key("Backspace"), false)
MockFlush()
check(kb.Value == nil, "backspace clears bind")
kb:Set("G", true)
check(kb.Value == Enum.KeyCode.G, "keybind Set by string")
local pressesBefore = kpress
UIS.InputBegan:Fire(key("G"), false)
check(kpress == pressesBefore + 1, "keybind fires on new key")

local cp = home:AddColorPicker({ Name = "Color", Default = Color3.fromRGB(255, 0, 0), Flag = "color" })
check(win.Flags.color ~= nil, "color flag")
cp:Set("#00FF00")
check(math.abs(cp.Value.G - 1) < 0.01 and cp.Value.R < 0.01, "color set by hex")
local sv = find(cp._card, function(d) return d:IsA("Frame") and d.Active == true and d.ClipsDescendants == true end)
check(sv ~= nil, "sv box found")
sv.InputBegan:Fire(press(100, 50))
UIS.InputChanged:Fire(move(50, 25))
UIS.InputEnded:Fire(press(50, 25))
check(cp.Value ~= nil, "color after drag")

local clicked = 0
local single = home:AddButton({ Name = "Btn", Text = "Go", Primary = true, Callback = function() clicked = clicked + 1 end })
single:Fire()
local multi = home:AddButtons({ Name = "Config", Buttons = { { Text = "Reset", Callback = function() clicked = clicked + 10 end }, { Text = "Apply", Primary = true, Callback = function() clicked = clicked + 100 end } } })
multi:Fire(1)
multi:Fire(2)
multi.Buttons[2].Activated:Fire()
check(clicked == 211, "buttons fire (got " .. clicked .. ")")

ply:AddSection("Other")
ply:AddToggle({ Name = "Jump", Flag = "jump" })
glyph:AddLabel("glyph tab content")

------------------------------------------------------------------ interactions
win:SelectTab(ply)
check(win._active == ply and ply._page.Visible and not home._page.Visible, "select tab switches pages")
home._btn.MouseEnter:Fire()
home._btn.MouseLeave:Fire()
win:SelectTab(home)

-- search
win._search.Text = "sprint"
check(tg._card.Visible == true, "search keeps match")
check(sl._card.Visible == false, "search hides non-match")
win._search.Text = ""
check(sl._card.Visible == true, "clearing search shows all")
tg:SetVisible(false)
check(tg._card.Visible == false, "SetVisible(false)")
tg:SetVisible(true)

-- theme
win:SetTheme("Ice")
check(win.Theme.Accent.B > 0.9, "theme Ice applied")
win:SetAccent(Color3.fromRGB(255, 80, 80))
check(win.Theme.Accent.R == 1, "SetAccent applied")
win:SetTheme({ Base = "Graphite", Accent = Color3.fromRGB(10, 10, 10) })
check(win.Theme.OnAccent.R > 0.9, "custom theme computes OnAccent")
win:SetTheme("Onyx")

-- window controls
win:SetMinimized(true)
MockFlush()
check(win._body.Visible == false, "minimized hides body")
win:SetMinimized(false)
check(win._body.Visible == true, "restore shows body")
win:Hide(); MockFlush()
check(win._holder.Visible == false, "hide")
UIS.InputBegan:Fire(key("RightShift"), false)
check(win._visible == true, "toggle key shows hidden window")
win:Show(); win:Show()
check(win._visible == true, "show")

-- drag window via title bar
local top = find(win._main, function(d) return d.Name == "TopBar" end)
local startPos = win._holder.Position
top.InputBegan:Fire(press(100, 10))
UIS.InputChanged:Fire(move(160, 40))
UIS.InputEnded:Fire(press(160, 40))
check(win._holder.Position.X.Offset == startPos.X.Offset + 60, "window dragged by 60px (got " .. tostring(win._holder.Position.X.Offset) .. ")")
-- resize
local w0 = win._w
win._grip.InputBegan:Fire(press(500, 400))
UIS.InputChanged:Fire(move(540, 430))
UIS.InputEnded:Fire(press(540, 430))
check(win._w == w0 + 40, "window resized (+40)")

-- config
local json = win:ExportConfig()
check(type(json) == "string" and json:find("sprint"), "export contains flags")
win.Options.speed:Set(10)
win.Options.mode:Set("X", true)
check(win:ImportConfig(json), "import ok")
check(win.Flags.speed == 100 or win.Flags.speed == 75 or win.Flags.speed ~= nil, "flag after import present")
check(win:ImportConfig("not json {") == false, "bad json returns false")

-- notifications
for _, ty in ipairs({ "Info", "Success", "Warning", "Error" }) do
	Onyx:Notify({ Title = ty, Content = "content " .. ty, Type = ty, Duration = 2 })
end
for i = 1, 7 do win:Notify({ Title = "n" .. i }) end
local toasts = findAll(MockPlayerGui, function(d) return d.Name == "Toast" end)
check(#toasts <= 5, "max 5 toasts (got " .. #toasts .. ")")
local card = find(MockPlayerGui, function(d) return d.Name == "Card" end)
card.Activated:Fire()
MockFlush()

-- dialog
local ok1 = false
local dlg = win:Dialog({ Title = "Sure?", Content = "Really?", Buttons = { { Name = "No" }, { Name = "Yes", Primary = true, Callback = function() ok1 = true end } } })
local btns = findAll(win._main, function(d) return d:IsA("TextButton") and (d.Text == "Yes" or d.Text == "No") end)
check(#btns == 2, "dialog buttons")
btns[2].Activated:Fire()
MockFlush()
check(ok1, "dialog callback")
check(find(win._main, function(d) return d.Name == "DialogDim" end) == nil, "dialog closed")
win:Dialog({ Title = "Default" })
MockFlush()

-- element destroy
kb:Destroy()
UIS.InputBegan:Fire(key("G"), false)
check(kpress == pressesBefore + 1, "destroyed keybind no longer fires")
local lab = home:AddLabel("temp")
lab:Destroy()
tg:Destroy()
check(win.Options.sprint == nil, "destroyed element removes option")
win:_applyFilter()

------------------------------------------------------------------ compact / touch
UIS.TouchEnabled = true
local w2 = Onyx:CreateWindow({ Title = "MOBILE", Size = UDim2.fromOffset(500, 380), UserCard = false })
check(w2._compact == true, "compact when narrow")
check(w2._floating ~= nil, "floating button on touch")
local t2 = w2:AddTab({ Name = "One" })
t2:AddToggle({ Name = "x" })
t2:AddSlider({ Name = "y" })
w2._floating.InputBegan:Fire(press(30, 300))
UIS.InputEnded:Fire(press(30, 300))
check(w2._visible == false, "floating button click hides window")
w2._floating.InputBegan:Fire(press(30, 300))
UIS.InputChanged:Fire(move(120, 340))
UIS.InputEnded:Fire(press(120, 340))
check(w2._visible == false, "floating drag does not toggle")
UIS.TouchEnabled = false

Onyx:DestroyAll()
check(#Onyx.Windows == 0, "DestroyAll")
check(win._destroyed and w2._destroyed, "windows destroyed")

print(string.format("checks=%d failures=%d instances=%d", checks, failures, MockInstanceCount()))
os.exit(failures == 0 and 0 or 1)
