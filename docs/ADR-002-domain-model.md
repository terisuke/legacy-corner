# ADR-002: ドメインモデルと不変条件

## ステータス: 提案中

## コンテキスト
ADR-001は技術分割（Autoload、JSON、UI）を定義したが、ゲームのドメイン境界と不変条件が未定義。
AIが正しいノード構成を作っても、ドメインルールを破壊する実装が可能な状態だった。

## ドメインモデル

### コアドメイン定義
> 遺産価値と衛生リスクのトレードオフを、不完全情報の下で裁くこと

### エンティティと値オブジェクト

```
GameSession（集約ルート）
├── session_id: String
├── state: GameState
├── turns_remaining: int
├── layers: Array[Layer]
├── rng: RandomNumberGenerator（seed固定可能）
└── audit_report: AuditReport（ゲーム終了時に生成）

Layer（エンティティ）
├── index: int (0-2)
├── items: Array[ItemInstance] (固定2個)
└── is_opened: bool

ItemInstance（エンティティ — ゲーム開始時にテンプレートから生成）
├── template_id: String（items.jsonのid）
├── name: String
├── years_old: int（テンプレートのrangeからRNG生成）
├── is_contaminated: bool（ゲーム開始時にRNG判定、プレイヤー非公開）
├── contamination_chance: float（計算済み、clamp(0.05, 0.85)）
├── washable: bool
├── wash_success_rate: float（計算済み、clamp(0.1, 0.9)）
├── discard_regret: float (0.0-1.0)
├── memory_text: String
├── inspection_result: InspectionResult?（null = 未検査）
└── decision: DecisionOutcome?（null = 未処理）

InspectionResult（値オブジェクト — 確率付き観測であり真実ではない）
├── tool_id: String
├── displayed_result: String ("contaminated" | "clean" | "inconclusive")
├── is_accurate: bool（プレイヤー非公開、スコア計算でも使わない）
└── turn_cost: int (= 1)

DecisionOutcome（値オブジェクト — 1アイテムにつき1回のみ生成）
├── action: String ("keep" | "discard" | "wash")
├── wash_succeeded: bool?（wash時のみ）
├── score_delta: int（この判断によるスコア変動）
├── triggered_regret: bool
└── turn_cost: int (= 1)

AuditReport（値オブジェクト — ゲーム終了時に1回だけ生成）
├── raw_score: int（加減算合計、負値あり得る）
├── normalized_score: int（0-100にclamp）
├── rank: String ("S" | "A" | "B" | "C" | "D")
├── grandma_comment: String
├── contamination_missed: Array[ItemInstance]（見逃した汚染アイテム）
├── regret_items: Array[ItemInstance]（後悔アイテム）
└── unprocessed_items: Array[ItemInstance]（未処理アイテム）
```

## ドメイン不変条件

### INV-1: 終端判断の一意性
> 1アイテムは1回だけ終端判断（keep/discard/wash）される。判断後の変更は不可。

**違反時**: DecisionSystemはdecision != nullのアイテムへの操作を拒否する。

### INV-2: スコアの不可視性
> スコアはAuditReport生成まで外部に公開しない。プレイ中のUI、ログ、シグナルにスコア値を含めない。

**違反時**: ScoreManagerはget_score()相当のpublicメソッドを持たない。calculate_final_score()のみがAuditReportを返す。

### INV-3: 検査結果は観測であり真実ではない
> InspectionResultのdisplayed_resultは確率的観測。is_accurateフラグはスコア計算に使わない。プレイヤーには「表示された結果」のみが見え、それが正しいかはゲーム終了まで不明。

**違反時**: UIがis_accurateを参照してはならない。

### INV-4: ターン消費の厳密性
> 判断=1ターン、ツール使用=1ターン。turns_remaining <= 0で未処理アイテムは自動的にunprocessedとなる。

**違反時**: GameManagerはturns_remaining <= 0の状態で判断/ツール操作を受け付けない。

### INV-5: RNG再現性
> 同一seedで同一のゲームセッションが再現可能。汚染判定、ツール精度、洗浄成功のすべてが同一RNGインスタンスから導出される。

### INV-6: データ駆動のシングルソース
> ゲームバランスに関わる数値はdata/*.jsonとADR-003のみが正。GDScriptにバランス値をハードコードしない。README/GDD内の数値はADR-003が上書きする。

## ドメインイベント（シグナル対応）

| イベント | 発火タイミング | ペイロード |
|---------|--------------|-----------|
| `layer_opened` | 層を開けた時 | layer_index |
| `item_inspected` | ツール使用完了時 | item_id, displayed_result |
| `decision_made` | 判断確定時 | item_id, action, result |
| `turn_consumed` | ターン消費時 | turns_remaining |
| `game_ended` | 全処理完了 or ターン切れ | end_reason ("completed" \| "timeout") |
| `audit_completed` | AuditReport生成完了 | AuditReport |

## 影響
- GameManager, ScoreManager, ContaminationSystem, DecisionSystemの全APIはこのドメインモデルに準拠する
- Issue #2, #3, #11, #12の完了条件にドメイン不変条件の遵守を追加する
