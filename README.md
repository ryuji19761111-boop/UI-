# 🔥 BlazeUI

Roblox 用の **カラフルで派手な UI ライブラリ**(クライアント側)。
アニメーション付きウィンドウ・タブ・スライダー・カラーピッカー・通知・紙吹雪まで全部入り。スマホ対応。

> サーバー + クライアント両対応版は今後追加予定です。

## ✨ 機能

- 🪟 ウィンドウ: ドラッグ移動 / 最小化 / 開閉アニメ / 回転グラデーション枠 / 起動イントロ
- 📑 タブ(絵文字 or `rbxassetid://` アイコン)、セクション、ラベル、段落、区切り線
- 🎛 コンポーネント: **Button / Toggle / Slider / Dropdown(複数選択OK) / Input / Keybind / ColorPicker**
- 🔔 通知(Info / Success / Warning / Error)、🎉 紙吹雪
- 🎨 テーマ 6 種: `Blaze` `Neon` `Candy` `Toxic` `Ocean` `Light` + 自作テーマ、実行中に切り替え可能
- 📱 スマホ: タッチ操作・フローティング開閉ボタン・コンパクトレイアウト自動切替
- 💾 `Flags` / `Options` と、設定の JSON 書き出し・読み込み

## 📦 インストール

### 方法 1: コピペ(いちばん簡単・スマホ OK)
1. Roblox Studio で `ReplicatedStorage` に **ModuleScript** を作り、名前を `BlazeUI` にする
2. [`src/BlazeUI.lua`](src/BlazeUI.lua) の中身を全部貼り付ける

### 方法 2: Rojo
```bash
rojo build -o BlazeUI.rbxm   # できた .rbxm を Studio にドラッグ
# または rojo serve で直接同期
```

### 方法 3: Wally(任意)
自分のパッケージ名で `wally.toml` を作って公開してください。

> ⚠️ 通常の Roblox ゲームでは `loadstring(game:HttpGet(...))` は使えません。
> ModuleScript として `require` する形で使います。

## 🚀 クイックスタート

`StarterPlayerScripts` に **LocalScript** を作る:

```lua
local BlazeUI = require(game:GetService("ReplicatedStorage"):WaitForChild("BlazeUI"))

local Window = BlazeUI:CreateWindow({
	Title = "My Game",
	Subtitle = "v1.0",
	Icon = "🔥",
	Theme = "Blaze",
	ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab({ Name = "メイン", Icon = "🏠" })

Main:AddSection("はじめの一歩")
Main:AddButton({
	Name = "お祝い",
	Callback = function() BlazeUI:Confetti() end,
})
Main:AddToggle({
	Name = "ライト", Default = true, Flag = "Light",
	Callback = function(on) print("light", on) end,
})
Main:AddSlider({
	Name = "速さ", Min = 8, Max = 100, Default = 16, Flag = "Speed",
	Callback = function(v) print(v) end,
})
```

完全なデモは [`examples/Demo.client.lua`](examples/Demo.client.lua)。

## 📚 API

### `BlazeUI:CreateWindow(config)`
| キー | 型 | 説明 |
|---|---|---|
| `Title` / `Subtitle` | string | タイトル/サブタイトル |
| `Icon` | string | 絵文字 (既定 🔥) |
| `Theme` | string \| table | テーマ名 or 自作テーマ |
| `Size` | UDim2 | オフセットで指定 (既定 620×410、画面に合わせて自動縮小) |
| `ToggleKey` | KeyCode | 開閉キー (既定 RightShift) |
| `Intro` | bool | 起動イントロ (既定 true) |
| `FloatingButton` | bool? | nil=タッチ端末のみ表示 |
| `Parent` | Instance | GUI の親 (既定 PlayerGui) |

### Window
`AddTab` `SelectTab` `Show` `Hide` `Toggle` `SetMinimized` `SetTheme` `Notify` `ExportConfig` `ImportConfig` `Destroy`
`Window.Flags[flag]` に現在値、`Window.Options[flag]` に要素オブジェクトが入ります。

### Tab
| メソッド | 主なオプション |
|---|---|
| `AddSection(name)` | |
| `AddLabel({Text})` | `:Set(text)` |
| `AddParagraph({Title, Content})` | `:Set(title, content)` |
| `AddDivider()` / `AddSpacer(h)` | |
| `AddButton` | `Name, Description, Icon, Callback` |
| `AddToggle` | `Name, Description, Default, Flag, Callback(bool)` |
| `AddSlider` | `Name, Min, Max, Default, Increment, Suffix, Flag, Callback(number)` |
| `AddDropdown` | `Name, Options, Default, Multi, Placeholder, Flag, Callback(value)` ・ `:Refresh(options, keep)` |
| `AddInput` | `Name, Default, Placeholder, NumbersOnly, Flag, Callback(text, enter)` |
| `AddKeybind` | `Name, Default(KeyCode), Mode("Press"/"Hold"), Flag, Callback, ChangedCallback` |
| `AddColorPicker` | `Name, Default(Color3), Flag, Callback(Color3)` |

すべての要素に `:Set(value, silent)` `:Get()` `:SetVisible(bool)` `:Destroy()` があります。

### 通知・演出
```lua
BlazeUI:Notify({ Title = "やったね", Content = "成功!", Type = "Success", Duration = 4 })
BlazeUI:Confetti()
```

### 自作テーマ
```lua
Window:SetTheme({
	Base = "Neon",                       -- 元にするテーマ (任意)
	Accent = Color3.fromRGB(255, 220, 0),
	Accent2 = Color3.fromRGB(255, 0, 100),
})
```
使えるキー: `Background Surface Elevated Accent Accent2 Text SubText Stroke Success Warning Danger`

## 🌐 GitHub で公開するには(スマホでも OK)

1. GitHub で新しいリポジトリを作る(例: `BlazeUI`)
2. このフォルダの中身をアップロード(**Add file → Upload files**。`src/` `examples/` などフォルダごと)
3. 「Releases」から `v1.0.0` を作ると、ダウンロード用ページができる

## 📝 License
MIT — 好きに使ってください。
