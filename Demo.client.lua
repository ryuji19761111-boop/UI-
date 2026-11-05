--[[
	ONYX UI デモ
	置き場所: StarterPlayer > StarterPlayerScripts に LocalScript として入れる
	Onyx (ModuleScript) は ReplicatedStorage に置いておく
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Onyx = require(ReplicatedStorage:WaitForChild("Onyx"))
local player = Players.LocalPlayer

local function getHumanoid()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("Humanoid")
end

local Window = Onyx:CreateWindow({
	Title = "ONYX",
	Theme = "Onyx",
	ToggleKey = Enum.KeyCode.RightShift,
})

-- Home -----------------------------------------------------------------
local Home = Window:AddTab({ Name = "Home" })
Home:AddSection("Welcome")
Home:AddParagraph({
	Title = "ONYX UI",
	Content = "タブ・スライダー・ドロップダウン・カラーピッカー・通知・ダイアログ入り。右上の検索で部品を絞り込めます。",
})
Home:AddButtons({
	Name = "Notifications",
	Description = "4 種類の通知",
	Buttons = {
		{
			Text = "Info",
			Callback = function()
				Onyx:Notify({ Title = "Info", Content = "ふつうのお知らせ", Type = "Info" })
			end,
		},
		{
			Text = "Success",
			Callback = function()
				Onyx:Notify({ Title = "Success", Content = "うまくいきました", Type = "Success" })
			end,
		},
		{
			Text = "Error",
			Primary = true,
			Callback = function()
				Onyx:Notify({ Title = "Error", Content = "エラーのお知らせ", Type = "Error" })
			end,
		},
	},
})
Home:AddButton({
	Name = "Dialog",
	Description = "確認ダイアログを開く",
	Text = "Open",
	Callback = function()
		Window:Dialog({
			Title = "確認",
			Content = "この操作を実行しますか?",
			Buttons = {
				{ Name = "Cancel" },
				{
					Name = "Run",
					Primary = true,
					Callback = function()
						Window:Notify({ Title = "Done", Type = "Success", Duration = 2 })
					end,
				},
			},
		})
	end,
})

-- Player ----------------------------------------------------------------
local PlayerTab = Window:AddTab({ Name = "Player" })
PlayerTab:AddSection("Movement")
PlayerTab:AddSlider({
	Name = "Walk Speed",
	Min = 8,
	Max = 100,
	Default = 16,
	Flag = "WalkSpeed",
	Callback = function(v)
		getHumanoid().WalkSpeed = v
	end,
})
PlayerTab:AddSlider({
	Name = "Jump Power",
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
PlayerTab:AddToggle({
	Name = "Infinite Jump",
	Description = "空中でもジャンプできる",
	Flag = "InfJump",
	Callback = function(on)
		Window:Notify({ Title = "Infinite Jump", Content = on and "On" or "Off", Duration = 2 })
	end,
})
UserInputService.JumpRequest:Connect(function()
	if Window.Flags.InfJump then
		getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

PlayerTab:AddSection("Input")
PlayerTab:AddInput({
	Name = "Memo",
	Placeholder = "Type here…",
	Flag = "Memo",
	Callback = function(text, enter)
		if enter then
			Window:Notify({ Title = "Saved", Content = text, Duration = 2 })
		end
	end,
})
PlayerTab:AddKeybind({
	Name = "Jump Key",
	Default = Enum.KeyCode.F,
	Flag = "JumpKey",
	Callback = function()
		getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end,
})

-- Visual ------------------------------------------------------------------
local Visual = Window:AddTab({ Name = "Visual" })
Visual:AddSection("Theme")
Visual:AddDropdown({
	Name = "Theme",
	Options = { "Onyx", "Graphite", "Ice", "Lime", "Amber", "Rose", "Violet" },
	Default = "Onyx",
	Flag = "Theme",
	Callback = function(name)
		if name then
			Window:SetTheme(name)
		end
	end,
})
Visual:AddColorPicker({
	Name = "Accent",
	Default = Color3.fromRGB(242, 242, 243),
	Flag = "Accent",
	Callback = function(color)
		Window:SetAccent(color)
	end,
})
Visual:AddSection("World")
Visual:AddSlider({
	Name = "Time of Day",
	Min = 0,
	Max = 24,
	Default = 14,
	Increment = 0.5,
	Flag = "Time",
	Callback = function(v)
		Lighting.ClockTime = v
	end,
})
Visual:AddDropdown({
	Name = "Interests",
	Options = { "Games", "Music", "Anime", "Sports", "Cooking" },
	Multi = true,
	Default = { "Games" },
	Flag = "Interests",
	Callback = function(list)
		print("selected:", table.concat(list, ", "))
	end,
})

-- Settings ------------------------------------------------------------------
local Settings = Window:AddTab({ Name = "Settings" })
Settings:AddSection("Window")
Settings:AddKeybind({
	Name = "Toggle Key",
	Description = "ウィンドウの開閉キー",
	Default = Enum.KeyCode.RightShift,
	ChangedCallback = function(key)
		if key then
			Window:SetToggleKey(key)
		end
	end,
})
Settings:AddSection("Config")
local saved
Settings:AddButtons({
	Name = "Config",
	Description = "Flag を付けた部品の値を JSON で保存/復元",
	Buttons = {
		{
			Text = "Export",
			Callback = function()
				saved = Window:ExportConfig()
				print(saved)
				Window:Notify({ Title = "Exported", Content = "出力ウィンドウを見てください", Type = "Success" })
			end,
		},
		{
			Text = "Import",
			Primary = true,
			Callback = function()
				if saved and Window:ImportConfig(saved) then
					Window:Notify({ Title = "Imported", Type = "Success" })
				else
					Window:Notify({ Title = "先に Export してください", Type = "Warning" })
				end
			end,
		},
	},
})
Settings:AddButton({
	Name = "Destroy UI",
	Description = "ウィンドウを完全に消す",
	Text = "Destroy",
	Callback = function()
		Window:Dialog({
			Title = "Destroy UI?",
			Content = "ウィンドウが完全に消えます。",
			Buttons = {
				{ Name = "Cancel" },
				{
					Name = "Destroy",
					Primary = true,
					Callback = function()
						Window:Destroy()
					end,
				},
			},
		})
	end,
})
