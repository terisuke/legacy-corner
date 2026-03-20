# ADR-001: ゲームアーキテクチャの基本方針

## ステータス: 提案中

## コンテキスト
「隅の遺産」はGodot 4.6.1-stableで開発するターン制判断シミュレーション。
MVPを最速で作るため、Godot標準機能のみで実装し、外部プラグインを使わない。

## 決定事項

### 1. 状態管理: enum + match文（ステートマシン）
**選択肢**:
- A) enum + match文（シンプル） ← **採用**
- B) Nodeベースのステートマシン
- C) 外部プラグイン（gd-YAFSM等）

**理由**: 状態数が少ない（6-7状態）。公式ドキュメントとGDQuestチュートリアルで十分なパターン。
MVPにNodeベースは過剰。

**根拠**: [GDQuest FSM Tutorial](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)

```gdscript
enum GameState { TITLE, LAYER_OPEN, ITEM_INSPECT, DECISION, GRANDMA_AUDIT, RESULT }
var current_state: GameState = GameState.TITLE
```

### 2. グローバル状態: Autoload シングルトン
**選択肢**:
- A) Autoload シングルトン ← **採用**
- B) リソースベースの状態管理
- C) シグナルバスのみ

**理由**: Godot公式推奨パターン。スコア・ターン数・ゲーム進行をシーン間で共有する最もシンプルな方法。

**根拠**: [Godot公式 Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)

Autoload対象:
- `GameManager` — ゲーム状態・ターン管理
- `ScoreManager` — スコア計算（プレイ中は内部計算のみ、表示しない）
- `DataLoader` — JSON読み込み・アイテム/セリフデータ保持

### 3. データ管理: JSON + FileAccess
**選択肢**:
- A) JSON ファイル ← **採用**
- B) Godot Resource (.tres)
- C) SQLite

**理由**: items.json, grandma_dialogues.json が既に存在。
ゲームバランス調整がコード変更なしで可能。
`FileAccess.open()` → `JSON.new().parse()` で2行で読める。

**根拠**: [Godot公式 JSON Class](https://docs.godotengine.org/en/stable/classes/class_json.html)

### 4. UI構成: Controlノードツリー
**選択肢**:
- A) Controlノード（Label, Button, TextureRect） ← **採用**
- B) Sprite2Dベースの自作UI

**理由**: Godot標準UIシステムで必要十分。
アンカー・コンテナによるレスポンシブ対応も標準機能。

**根拠**: [Godot公式 Control](https://docs.godotengine.org/en/stable/classes/class_control.html)

### 5. シーン構成: 1メインシーン + サブシーンinstantiate
**選択肢**:
- A) 1メインシーン内で状態切替 ← **採用**
- B) SceneTree.change_scene_to_packed() でシーン遷移

**理由**: MVPの画面数が少ない（実質3画面: ゲーム本体 / 祖母レビュー / リザルト）。
シーン遷移のオーバーヘッドが不要。サブシーンをinstantiateして表示/非表示で切替。

### 6. ターン管理: 変数カウント（Timerノード不使用）
**選択肢**:
- A) ターン数カウント変数 ← **採用**
- B) リアルタイムTimer + カウントダウン

**理由**: ユーザー要望でターン数制限を採用。リアルタイムではない。
ターン消費はプレイヤーのアクション（判断/ツール使用）でのみ発生。

### 7. 乱数管理: RandomNumberGenerator
**選択肢**:
- A) RandomNumberGenerator インスタンス ← **採用**
- B) グローバル randf() / randi()

**理由**: seed制御でデバッグ・リプレイ対応が容易。
汚染判定・ツール精度の乱数を再現可能にする。

## 影響
- 全実装がGodot 4.6標準機能のみで完結
- 外部依存ゼロ → ビルド・配布が単純
- MVPからの拡張時、Autoloadを増やすだけで対応可能
