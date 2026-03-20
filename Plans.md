# 実装計画: 隅の遺産 MVP

> GitHub Issues: https://github.com/terisuke/legacy-corner/issues

## フェーズ0: 設計・準備 ✅
- [x] プロジェクト初期化（Godot 4.6.1）
- [x] ディレクトリ構成
- [x] データJSON（items.json, grandma_dialogues.json）
- [x] CLAUDE.md
- [x] ADR-001: ゲームアーキテクチャ
- [x] ゲームデザインドキュメント
- [x] GitHub Issue作成（Epic × 5 + 子Issue × 13）

## Wave 1: コアシステム（Autoload） — Epic #1
- [ ] #19 ADR-002/003 レビュー・承認（実装着手前に必要）
- [ ] #2 `scripts/core/game_manager.gd` — GameState enum、ターン管理、状態遷移
- [ ] #3 `scripts/core/score_manager.gd` — スコア計算ロジック（非表示管理含む）
- [ ] #4 `scripts/core/data_loader.gd` — JSON読み込み、アイテム/セリフデータ保持
- [ ] #5 project.godot にAutoload登録

## Wave 2: メインゲーム画面 — Epic #6（Wave 1完了後）
- [ ] #7 `scenes/main/main.tscn` + `main.gd` — メインシーン、状態に応じたUI切替
- [ ] #8 `scenes/box/layer.tscn` + `layer.gd` — 層シーン、アイテム配置
- [ ] #9 `scenes/box/item_card.tscn` + `item_card.gd` — アイテム表示カード

## Wave 3: 判断システム — Epic #10（Wave 2完了後）
- [ ] #11 `scripts/systems/contamination_system.gd` — 汚染判定、ツール検査（偽陽性/偽陰性）
- [ ] #12 `scripts/systems/decision_system.gd` — 3択処理、洗浄判定、後悔イベント

## Wave 4: 祖母レビュー & リザルト — Epic #13（Wave 3完了後）
- [ ] #14 `scenes/grandma/grandma_audit.tscn` + `grandma_audit.gd` — 祖母レビュー画面
- [ ] #15 `scenes/ui/result_screen.tscn` + `result_screen.gd` — リザルト画面

## Wave 5: タイトル & ゲームループ — Epic #16（Wave 4完了後）
- [ ] #17 `scenes/ui/title_screen.tscn` + `title_screen.gd` — タイトル画面
- [ ] #18 ゲームループ接続（リトライフロー）— **MVP完成**

## 将来: ポリッシュ（MVP後）
- [ ] SE/BGM追加
- [ ] アイテム画像差し替え
- [ ] アニメーション（スコアバー、祖母登場）
- [ ] シェアボタン
- [ ] Gun Legacy Corner DLC

## 依存関係
```
Wave 1 (#1) → Wave 2 (#6) → Wave 3 (#10) → Wave 4 (#13) → Wave 5 (#16)
```

## 実装方針
- Godot 4.6.1-stable 標準機能のみ（外部プラグインなし）
- GDScript、enum + match文のステートマシン
- データ駆動（JSON）、コードにバランス値ハードコードしない
- 各シーンはF6で単体テスト可能に設計
