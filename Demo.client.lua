--[[ 
    ONYX UI デモ (Stealth / Security Enhanced)
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
	Title = "System",
	Theme = "Onyx",
	ToggleKey = Enum.KeyCode.RightShift,
})  

-- Home -----------------------------------------------------------------
local Home = Window:AddTab({ Name = "Home" })
Home:AddSection("Overview")
Home:AddParagraph({
	Title = "Dashboard",
	Content = "パネルシステム稼働中",
})
Home:AddButtons({
	Name = "Actions",
	Description = "システム通知テスト",
	Buttons = {
		{
			Text = "Info",
			Callback = function()
				Onyx:Notify({ Title = "System", Content = "ステータス正常", Type = "Info" })
			end,
		},
		{
			Text = "Success",
			Callback = function()
				Onyx:Notify({ Title = "Success", Content = "処理完了", Type = "Success" })
			end,
		},
		{
			Text = "Error",
			Primary = true,
			Callback = function()
				Onyx:Notify({ Title = "Alert", Content = "警告レベル: 低", Type = "Error" })
			end,
		},
	},
})
Home:AddButton({
	Name = "Dialog",
	Description = "確認パネル",
	Text = "Open",
	Callback = function()
		Window:Dialog({
			Title = "確認",
			Content = "処理を実行しますか?",
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
PlayerTab:AddSection("Parameters")
PlayerTab:AddSlider({
	Name = "Speed Scale",
	Min = 8,
	Max = 32, -- 極端な数値を避けて制限
	Default = 16,
	Flag = "SpeedScale",
	Callback = function(v)
		local hum = getHumanoid()
		if hum then
			hum.WalkSpeed = v
		end
	end,
})
PlayerTab:AddSlider({
	Name = "Jump Scale",
	Min = 25,
	Max = 100, -- 極端な数値を避ける
	Default = 50,
	Flag = "JumpScale",
	Callback = function(v)
		local hum = getHumanoid()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = v
		end
	end,
})
PlayerTab:AddToggle({
	Name = "Assist Mode",
	Description = "補助機能の有効化",
	Flag = "AssistMode",
	Callback = function(on)
		Window:Notify({ Title = "Assist", Content = on and "Active" : "Standby", Duration = 2 })
	end,
})

PlayerTab:AddSection("Input")
PlayerTab:AddInput({
	Name = "Note",
	Placeholder = "input...",
	Flag = "NoteInput",
	Callback = function(text, enter)
		if enter then
			Window:Notify({ Title = "Saved", Content = "Saved.", Duration = 2 })
		end
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
Visual:AddSection("Environment")
Visual:AddSlider({
	Name = "Clock Time",
	Min = 0,
	Max = 24,
	Default = 14,
	Increment = 0.5,
	Flag = "Time",
	Callback = function(v)
		Lighting.ClockTime = v
	end,
})

-- Settings ------------------------------------------------------------------
local Settings = Window:AddTab({ Name = "Settings" })
Settings:AddSection("System")
Settings:AddKeybind({
	Name = "Toggle Key",
	Description = "UI表示切替",
	Default = Enum.KeyCode.RightShift,
	ChangedCallback = function(key)
		if key then
			Window:SetToggleKey(key)
		end
	end,
})
Settings:AddButton({
	Name = "Unload UI",
	Description = "UIを完全にアンロード",
	Text = "Unload",
	Callback = function()
		Window:Dialog({
			Title = "Unload?",
			Content = "インターフェースを終了します。",
			Buttons = {
				{ Name = "Cancel" },
				{
					Name = "Exit",
					Primary = true,
					Callback = function()
						Window:Destroy()
					end,
				},
			},
		})
	end,
})
