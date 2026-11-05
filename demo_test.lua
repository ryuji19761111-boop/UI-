-- デモ (examples/Demo.client.lua) を擬似環境で読み込み、全ボタンを押してエラーが出ないか確認するスモークテスト
-- 実行: リポジトリ直下で  lua tests/demo_test.lua
local base = (...) or "tests"
dofile(base .. "/mock.lua")

-- デモ用の追加モック
local rs = Instance.new("ReplicatedStorage")
local mod = Instance.new("ModuleScript")
mod.Name = "Onyx"
mod.Parent = rs
MockServices.ReplicatedStorage = rs
MockServices.Lighting = {}
MockServices.UserInputService.JumpRequest = MockSignal.new()
local char = Instance.new("Model")
local hum = Instance.new("Humanoid")
hum.Name = "Humanoid"
hum.Parent = char
hum.ChangeState = function() end
MockServices.Players.LocalPlayer.Character = char
char.WaitForChild = nil
require = function(m) return dofile(base .. "/../src/Onyx.lua") end

local warns = 0
local oldWarn = warn
warn = function(...) warns = warns + 1 oldWarn(...) end

dofile(base .. "/../examples/Demo.client.lua")
MockFlush()

-- 全ボタンを押してみる (ダイアログの Destroy なども含む)
local pressed = 0
for round = 1, 3 do
	local buttons = {}
	for _, d in ipairs(MockPlayerGui:GetDescendants()) do
		if d:IsA("TextButton") then buttons[#buttons + 1] = d end
	end
	for _, b in ipairs(buttons) do
		b.Activated:Fire()
		pressed = pressed + 1
		MockFlush()
	end
end
print(string.format("demo ok: pressed=%d warns=%d instances=%d", pressed, warns, MockInstanceCount()))
os.exit(warns == 0 and 0 or 1)
