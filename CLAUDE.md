# Legacy Corner - 隅の遺産 ～重箱の隠れ汚染を暴け～

## プロジェクト概要
10年放置された「おばあちゃんの重箱」を清掃する遺産清掃シミュレーションゲーム。
見えない汚染を暴きながら、捨てるか残すかの連続判断を迫られ、最後に祖母の理不尽レビュー（ルールベース）を受ける。

## 技術スタック
- **エンジン**: Godot 4.6.1-stable (GL Compatibility)
- **言語**: GDScript
- **解像度**: 1280x720 (canvas_items stretch)
- **対象プラットフォーム**: PC (Steam/itch.io)

## ディレクトリ構成
```
legacy-corner/
├── assets/
│   ├── sprites/      # キャラクター・UI・アイテム画像
│   ├── audio/        # BGM・SE
│   ├── fonts/        # フォント
│   └── vfx/          # エフェクト（UV光・汚染可視化）
├── scenes/
│   ├── main/         # メインシーン・ゲームループ
│   ├── box/          # 重箱・レイヤーシーン
│   ├── grandma/      # おばあちゃん審判シーン
│   └── ui/           # UIコンポーネントシーン
├── scripts/
│   ├── core/         # ゲームループ・状態管理（autoload等）
│   ├── systems/      # 汚染検知・判断・スコアリングシステム
│   └── ui/           # UIコントローラスクリプト
├── data/
│   ├── items.json            # アイテム定義
│   └── grandma_dialogues.json # 祖母セリフ定義
├── docs/             # 設計ドキュメント
├── builds/           # ビルド出力 (.gitignore)
├── addons/           # Godot プラグイン
└── CLAUDE.md
```

## コーディング規約
- GDScript: Godot公式スタイルガイド準拠
- snake_case（変数・関数）、PascalCase（クラス・ノード名）
- シグナル名は過去形（`item_selected`, `layer_opened`）
- Autoloadは `scripts/core/` に配置、`GameManager`, `ScoreManager` 等
- データ駆動: ゲームバランスは JSON で管理（`data/`）、コードにハードコードしない
- シーンは独立動作可能に（F6で単体テスト可能）

## ビルド & 実行
```bash
# Godot エディタで開く
open -a Godot project.godot

# コマンドラインで実行（Godot がPATHにある場合）
godot --path . --main-scene res://scenes/main/main.tscn
```

## ゲームの状態遷移
```
Title → BoxSelect → LayerOpen → ItemInspect → Decision(残す/捨てる/洗う)
  → 次のアイテム or 次のレイヤー → GrandmaAudit → ScoreResult → (Share/Retry)
```

## 主要システム（Autoload）
1. **GameManager**: ゲーム状態遷移（enum FSM）、ターン管理、RNG管理
2. **ScoreManager**: スコア計算（プレイ中非公開）、正規化、ランク判定
3. **DataLoader**: JSON読み込み、アイテム/セリフデータ保持

## ゲームシステム
4. **ContaminationSystem**: 汚染判定（clamp 0.05-0.85）、ツール検査（偽陽性/偽陰性あり）
5. **DecisionSystem**: 3択判断、洗浄判定、後悔イベント

## ドメイン不変条件（ADR-002）
> 実装時に必ず遵守。違反するとゲームの核が壊れる。

- **INV-1**: 1アイテムは1回だけ終端判断される。判断後の変更不可。
- **INV-2**: スコアはAuditReport生成まで外部に公開しない。
- **INV-3**: 検査結果は確率付き観測。is_accurateをUIに公開しない。
- **INV-4**: turns_remaining <= 0 で操作を受け付けない。
- **INV-5**: 同一seedで同一セッション再現可能。
- **INV-6**: バランス値はdata/*.jsonとADR-003のみが正。ハードコード禁止。

## 数値のSource of Truth
```
ADR-003 > data/*.json > docs/game-design.md > README.md
```

## 設計ドキュメント
- `docs/ADR-001-game-architecture.md` — 技術アーキテクチャ判断
- `docs/ADR-002-domain-model.md` — ドメインモデルと不変条件
- `docs/ADR-003-balance-invariants.md` — バランス数値と受け入れシナリオ
- `docs/game-design.md` — ゲームデザイン概要
