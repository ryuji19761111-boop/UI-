# ONYX UI

Roblox 用の **黒基調・白文字の落ち着いた UI ライブラリ**(クライアント側)。
細い境界線と、ほんの少しの光だけで見せるミニマルなデザインです。スマホにも対応しています。

> サーバー + クライアント両対応版は今後追加予定です。

## 特徴

- **ウィンドウ**: ドラッグ移動 / 右下でサイズ変更 / 最小化 / 開閉アニメ / 検索 / スマホ用フローティングボタン
- **タブ**・セクション・ラベル・段落・区切り線
- **部品**: Button / Toggle / Slider / Dropdown(複数選択OK) / Input / Keybind / ColorPicker
- **通知**(Info / Success / Warning / Error)と **ダイアログ**
- **テーマ 7 種**: `Onyx` `Graphite` `Ice` `Lime` `Amber` `Rose` `Violet`
  + 実行中のアクセントカラー変更 + 自作テーマ
- `Flags` / `Options`、設定の JSON 書き出し・読み込み
- 画像ファイル不要(アイコンは図形で描画。`rbxassetid://` も指定可)

## インストール

### 方法 1: コピペ(スマホでも OK)
1. Roblox Studio で `ReplicatedStorage` に **ModuleScript** を作り、名前を `Onyx` にする
2. [`src/Onyx.lua`](src/Onyx.lua) の中身を全部貼り付ける

### 方法 2: Rojo
```bash
rojo build -o Onyx.rbxm   # できた .rbxm を Studio にドラッグ
# または rojo serve で直接同期
```

> 通常の Roblox ゲームでは `loadstring(game:HttpGet(...))` は使えません。
> ModuleScript として `require` する形で使います。

## クイックスタート

`StarterPlayerScripts` に **LocalScript** を作る:

```lua
local Onyx = require(game:GetService("ReplicatedStorage"):WaitForChild("Onyx"))

local Window = Onyx:CreateWindow({
	Title = "MY GAME",
	Theme = "Onyx",
	ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab({ Name = "Main" })

Main:AddSection("Basics")
Main:AddToggle({
	Name = "Auto Sprint",
	Description = "押しっぱなし不要",
	Default = true,
	Flag = "Sprint",
	Callback = function(on) print("sprint", on) end,
})
Main:AddSlider({
	Name = "Walk Speed", Min = 8, Max = 100, Default = 16, Flag = "Speed",
	Callback = function(v) print(v) end,
})
Main:AddButtons({
	Name = "Config",
	Buttons = {
		{ Text = "Reset", Callback = function() end },
		{ Text = "Apply", Primary = true, Callback = function() Window:Notify({ Title = "Applied", Type = "Success" }) end },
	},
})
```

完全なデモは [`examples/Demo.client.lua`](examples/Demo.client.lua)。

## API

### `Onyx:CreateWindow(config)`
| キー | 型 | 説明 |
|---|---|---|
| `Title` / `Subtitle` | string | タイトル / 小さな補足(既定は `client · v1.0.0`、`""` で非表示) |
| `Theme` | string \| table | テーマ名 or 自作テーマ(既定 `Onyx`) |
| `Size` | UDim2 | オフセットで指定(既定 760×480。画面に合わせて自動縮小、幅 560 未満はコンパクト表示) |
| `ToggleKey` | KeyCode | 開閉キー(既定 RightShift) |
| `Search` | bool | タイトルバーの検索(既定 true。幅 640 未満では非表示) |
| `Resizable` | bool | 右下でサイズ変更(既定 true) |
| `UserCard` | bool | サイドバー下のプレイヤー表示(既定 true) |
| `FloatingButton` | bool? | nil = タッチ端末のみ表示 |
| `Visible` | bool | 作成直後に表示(既定 true) |
| `Parent` | Instance | GUI の親(既定 PlayerGui) |

### Window
`AddTab` `SelectTab` `Show` `Hide` `Toggle` `SetMinimized` `SetToggleKey` `SetTheme` `SetAccent` `Notify` `Dialog` `ExportConfig` `ImportConfig` `Destroy`

`Window.Flags[flag]` に現在値、`Window.Options[flag]` に部品オブジェクトが入ります(`Flag` を付けた部品のみ)。

### Tab
| メソッド | 主なオプション |
|---|---|
| `AddSection(name)` | |
| `AddLabel({Text})` | `:Set(text)` |
| `AddParagraph({Title, Content})` | `:Set(title, content)` |
| `AddDivider()` / `AddSpacer(height)` | |
| `AddButton` | `Name, Description, Text, Primary, Callback` |
| `AddButtons` | `Name, Description, Buttons = { {Text, Primary, Callback}, ... }` |
| `AddToggle` | `Name, Description, Default, Flag, Callback(bool)` |
| `AddSlider` | `Name, Min, Max, Default, Increment, Suffix, Flag, Callback(number)` |
| `AddDropdown` | `Name, Options, Default, Multi, Placeholder, Flag, Callback(value)` ・ `:Refresh(options, keep)` `:Open()` `:Close()` |
| `AddInput` | `Name, Default, Placeholder, NumbersOnly, Flag, Callback(text, enter)` |
| `AddKeybind` | `Name, Default, Mode("Press"/"Hold"/"Toggle"), Flag, Callback, ChangedCallback(KeyCode)` |
| `AddColorPicker` | `Name, Default(Color3), Flag, Callback(Color3)` |

すべての部品に `:Set(value, silent)` `:Get()`(値を持つもの)`:SetVisible(bool)` `:Destroy()` があります。
Keybind は Backspace で解除、Escape でキャンセルできます。

### 通知・ダイアログ
```lua
Onyx:Notify({ Title = "Saved", Content = "設定を保存しました", Type = "Success", Duration = 4 })

Window:Dialog({
	Title = "確認",
	Content = "実行しますか?",
	Buttons = {
		{ Name = "Cancel" },
		{ Name = "Run", Primary = true, Callback = function() end },
	},
})
```
`Type`: `Info` / `Success` / `Warning` / `Error`

### テーマ
```lua
Window:SetTheme("Ice")                                   -- プリセット
Window:SetAccent(Color3.fromRGB(255, 120, 80))           -- アクセントだけ変更
Window:SetTheme({ Base = "Graphite", Accent = Color3.fromRGB(125, 211, 252) })  -- 自作
```
使えるキー: `Background Sidebar Surface Hover Control Popup Stroke StrokeStrong Text SubText Muted Accent OnAccent Track Success Warning Danger`

### 設定の保存
```lua
local json = Window:ExportConfig()   -- Flag 付き部品の値を JSON 文字列に
Window:ImportConfig(json)            -- 復元
```
保存先(DataStore や自分のサーバーなど)はお好みで。

## テスト

Roblox なしで動く簡易モック上で、全部品の操作(クリック・ドラッグ・検索・テーマ切替・設定の書き出し/読み込みなど)を実行するテストが入っています。

```bash
lua tests/test.lua        # 部品・ウィンドウ操作の単体テスト (Lua 5.4)
lua tests/demo_test.lua   # デモを読み込んで全ボタンを押すスモークテスト
```

モックは本物の Roblox ではないので、見た目や挙動の最終確認は Studio で行ってください。

## GitHub で公開するには(スマホでも OK)

1. GitHub で新しいリポジトリを作る(例: `Onyx`)
2. このフォルダの中身を Add file → Upload files でアップロード(`src/` `examples/` `tests/` などフォルダごと)
3. Releases から `v1.0.0` を作る

## License
MIT
