# 隅の遺産 ～重箱の隠れ汚染を暴け～
**Legacy Corner: The Hidden Filth**

> 10年放置された「おばあちゃんの重箱」を、見えない汚染を暴きながら、捨てるか残すかの連続判断を迫られ、最後に祖母の理不尽レビューを受ける遺産清掃シミュレーション。

---

## コアゲーム性

1. **Legacy Box** — 開封するたびに年数ランダム＋隠れ汚染確率
2. **Hidden Contamination** — UVライトで見えない汚れを探す（MVP: UVライトのみ）
3. **判断の連続** — 残す / 捨てる / 洗う の3択（正解がわからない不完全情報下で決断）
4. **Grandma Audit** — 理不尽レビューのおばあちゃん審判（スコアはここで初公開）
5. **ターン制限** — 全10ターンで全部は調べられない（将来: Time Attack モード）

> 詳細な設計は `docs/game-design.md` を参照。数値バランスは `docs/ADR-003-balance-invariants.md` が正。

---

## MVP スコープ

- 1箱・3層・6アイテム（テンプレート6種から生成）
- 判断3択（残す / 捨てる / 洗う）+ ツール検査
- ターン制限: 10ターン
- UVライト1個（判定不能15% / 偽陽性≈5% / 偽陰性≈3% / 条件付き確率モデル）
- スコア正規化 0-100 + ランクS-D
- 祖母レビュー（スコア帯別コメント5種 + 汚染発見3種 + 完璧1種）
- リトライ機能

## セットアップ

### 前提条件
- macOS / Windows / Linux
- Godot 4.6.1-stable

### インストール & 起動
```bash
# macOS: Godot 4.6.1 インストール
brew install --cask godot

# プロジェクトを開く
# Godot を起動 → 「Import」→ project.godot を選択

# またはコマンドラインから直接起動
godot --path . --main-scene res://scenes/main/main.tscn
```

### ディレクトリ構成
| ディレクトリ | 役割 |
|-------------|------|
| `scenes/main/` | メインシーン・ゲームループ |
| `scenes/box/` | 重箱・層のシーン |
| `scenes/ui/` | HUD・メニューシーン |
| `scenes/grandma/` | おばあちゃん審判シーン |
| `scripts/core/` | ゲームループ・状態管理（Autoload） |
| `scripts/systems/` | 汚染検知・判断・スコアリング |
| `scripts/ui/` | UIロジック |
| `assets/sprites\|audio\|fonts\|vfx/` | アセット類 |
| `data/` | JSON データ（アイテム・セリフ定義） |
| `addons/` | Godot プラグイン |
| `builds/` | ビルド出力（.gitignore対象） |

### 実装の開始点
`scenes/main/main.tscn` をメインシーンとして作成するところからスタート。

---

## 将来のDLC

- **Gun Legacy Corner** — 銃箱モード（火薬残渣・暴発エンド）
