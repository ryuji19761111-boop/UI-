--[[
	BlazeUI デモ
	置き場所: StarterPlayer > StarterPlayerScripts に LocalScript として入れる
	BlazeUI (ModuleScript) は ReplicatedStorage に置いておく
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlazeUI = require(ReplicatedStorage:WaitForChild("BlazeUI"))
local player = Players.LocalPlayer

local function getHumanoid()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("Humanoid")
end

local Window = BlazeUI:CreateWindow({
	Title = "BlazeUI デモ",
	Subtitle = "v" .. BlazeUI.Version .. "  •  クライアント版",
	Icon = "🔥",
	Theme = "Blaze",
	ToggleKey = Enum.KeyCode.RightShift,
})

-- ホーム ---------------------------------------------------------------
local Home = Window:AddTab({ Name = "ホーム", Icon = "🏠" })
Home:AddSection("ようこそ")
Home:AddParagraph({
	Title = "BlazeUI へようこそ!",
	Content = "タブ、スライダー、ドロップダウン、カラーピッカー、通知、紙吹雪まで全部入り。右上の — で最小化、✕ で閉じる(RightShift で再表示)。",
})
Home:AddButton({
	Name = "紙吹雪をだす 🎉",
	Description = "お祝いしたい時に押してね",
	Callback = function()
		BlazeUI:Confetti()
	end,
})
Home:AddButton({
	Name = "通知テスト",
	Description = "4種類の通知を順番に出します",
	Icon = "🔔",
	Callback = function()
		BlazeUI:Notify({ Title = "Info", Content = "ふつうのお知らせ", Type = "Info" })
		task.wait(0.3)
		BlazeUI:Notify({ Title = "Success", Content = "うまくいった!", Type = "Success" })
		task.wait(0.3)
		BlazeUI:Notify({ Title = "Warning", Content = "ちょっと注意", Type = "Warning" })
		task.wait(0.3)
		BlazeUI:Notify({ Title = "Error", Content = "エラーのお知らせ", Type = "Error" })
	end,
})

-- プレイヤー -------------------------------------------------------------
local Player = Window:AddTab({ Name = "プレイヤー", Icon = "🏃" })
Player:AddSection("ステータス")
Player:AddSlider({
	Name = "歩く速さ",
	Min = 8,
	Max = 100,
	Default = 16,
	Suffix = "",
	Flag = "WalkSpeed",
	Callback = function(v)
		getHumanoid().WalkSpeed = v
	end,
})
Player:AddSlider({
	Name = "ジャンプ力",
	Min = 25,
	Max = 200,
	Default = 50,
	Flag = "JumpPower",
	Callback = function(v)
		local hum = getHumanoid()
		hum.UseJumpPower = true
		hum.JumpPower = v
	end,
})
Player:AddToggle({
	Name = "無限ジャンプ",
	Description = "空中でもジャンプできる",
	Default = false,
	Flag = "InfJump",
	Callback = function(on)
		BlazeUI:Notify({ Title = "無限ジャンプ", Content = on and "オン" or "オフ", Type = on and "Success" or "Info", Duration = 2 })
	end,
})
game:GetService("UserInputService").JumpRequest:Connect(function()
	if Window.Flags.InfJump then
		getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

Player:AddSection("そのほか")
Player:AddInput({
	Name = "表示名メモ",
	Placeholder = "なんでも入力",
	Flag = "Memo",
	Callback = function(text, enter)
		if enter then
			BlazeUI:Notify({ Title = "保存", Content = text, Type = "Info", Duration = 2 })
		end
	end,
})
Player:AddKeybind({
	Name = "ジャンプ ボタン",
	Default = Enum.KeyCode.F,
	Flag = "FKey",
	Callback = function()
		getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end,
})

-- 見た目 ----------------------------------------------------------------
local Look = Window:AddTab({ Name = "見た目", Icon = "🎨" })
Look:AddSection("テーマ")
Look:AddDropdown({
	Name = "テーマ",
	Options = { "Blaze", "Neon", "Candy", "Toxic", "Ocean", "Light" },
	Default = "Blaze",
	Flag = "Theme",
	Callback = function(name)
		if name then
			Window:SetTheme(name)
		end
	end,
})
Look:AddColorPicker({
	Name = "ライトの色",
	Default = Color3.fromRGB(255, 122, 24),
	Flag = "LightColor",
	Callback = function(color)
		game:GetService("Lighting").Ambient = color
	end,
})
Look:AddDropdown({
	Name = "好きなもの(複数OK)",
	Options = { "ゲーム", "アニメ", "音楽", "スポーツ", "料理" },
	Multi = true,
	Default = { "ゲーム" },
	Flag = "Likes",
	Callback = function(list)
		print("えらんだもの:", table.concat(list, ", "))
	end,
})

-- 設定 ------------------------------------------------------------------
local Settings = Window:AddTab({ Name = "設定", Icon = "⚙️" })
Settings:AddSection("設定の保存")
local saved
Settings:AddButton({
	Name = "設定を書き出す",
	Description = "いまの Flags を JSON 文字列にします",
	Callback = function()
		saved = Window:ExportConfig()
		print(saved)
		BlazeUI:Notify({ Title = "書き出し完了", Content = "出力ウィンドウを見てね", Type = "Success" })
	end,
})
Settings:AddButton({
	Name = "設定を読み込む",
	Callback = function()
		if saved and Window:ImportConfig(saved) then
			BlazeUI:Notify({ Title = "読み込み完了", Type = "Success" })
		else
			BlazeUI:Notify({ Title = "先に書き出してね", Type = "Warning" })
		end
	end,
})
Settings:AddButton({
	Name = "ウィンドウを消す",
	Icon = "🗑",
	Callback = function()
		Window:Destroy()
	end,
})
