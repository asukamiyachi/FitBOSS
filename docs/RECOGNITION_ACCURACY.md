# 腕立て伏せ認識：評価と改善（2026-11-02）

## 結論と測定範囲

**実機の認識精度が向上したとはまだ結論していない。** 最新main `0525d9ea37b19749a29f4b5e49808bc318c6b543` を基準に、手作りの合成26試行を同じ入力で比較した。MAE **0.269231→0回/試行**、FP **2→0**、FN **5→0**。これは既知の不具合を含む回帰セットであり、独立した人物・撮影条件の評価セットでも、統計的な精度保証でもない。「30%以上改善」という実機目標の達成を主張しない。

ソース、合成テスト、通常macOSビルド、公式Firebase SDKコンパイルを検証した。内蔵カメラについてはアプリの開始→人体未検出の案内・0回表示→停止だけをアクセシビリティテキストで確認し、検証アプリを終了した。映像を閲覧・録画・撮影・外部送信せず、運動記録も保存していない。正解付き腕立て試行、骨格の位置合わせ、他カメラの評価は未実施。

## 調査したデータフローと境界

`AVCaptureSession（sessionQueue） → AVCaptureVideoDataOutput → FrameProcessor/Vision（processingQueue、逐次・12fps目安） → main → CameraRecognitionState → PushUpEvaluator → SwiftUI`

- previewは引き続き `AVCaptureVideoPreviewLayer`。生映像と関節はメモリ内のみ。診断CSV、録画、カメラ画像のスクリーンショット、送信処理は追加していない。
- 入力sampleのpresentation timestampを `session.synchronizationClock` からhost clockへ変換。到着・処理時刻ではなく撮影時刻を状態機械へ渡す。Apple SDKの契約に基づく。12fpsの間引き、late-frame破棄、Vision request生成方式、ROI、入力解像度は変更しない。
- mainの認識revisionと撮影時刻の下限を、開始・停止・カメラ切替・カウントリセットで更新する。設定完了時にも境界を更新し、設定中に旧カメラが生成したバッファも排除する。revision/clockの受け渡しはlockで同期し、推論はlock外で逐次実行。
- 生体の3D姿勢・フォーム・本人識別は評価しない。最初のVision観測と片腕の2D角度を使う実験的方式を維持。

## 根拠、採用した修正、採用しなかった案

| ソース/合成で再現した問題 | 最小修正と安全条件 |
| --- | --- |
| 連続2サンプルが10ms間隔でも下姿勢を確定し、後で1回と数える | 2観測に加え、端点の連続観測が80ms以上必要。公称12fpsの既存2フレーム（約83ms）を大きく変えない暫定値 |
| 単発nil/低信頼/手首欠落ですぐ中途回数を破棄 | 最後の有効観測から250ms以内、同じ腕、同じ端点に復帰した場合のみ再確認。復帰後も2観測かつ80ms必要。復帰サンプルでは位相遷移・加算しない。欠落中に反対の端点へ動いた場合は破棄 |
| NaN時刻で比較が成立せず、途中回数を完成できる | 非有限/負時刻を拒否、重複/逆行は途中状態を破棄して該当観測も拒否。長いgapは中途回数を捨て、有効な新フレームから再基準化 |
| 12fpsのちょうど250msが丸めで250ms未満になりFN | 時間比較に1µsの数値誤差許容を適用。大きいuptimeでも回帰テスト。動作閾値を緩める調整とは区別 |
| 正規化X/Yを同じ尺度として角度を計算し、横長画像の角度が歪む | `PoseFrame.imageAspectRatio` に幅/高さを追加（既存呼出しは既定1で互換）。角度だけX差に比率を掛ける。overlay用の正規化座標は不変 |
| 開始/切替/リセット前の推論完了が新しい計測に混入し得る | capture revisionとhost撮影時刻の二重境界。ハード中断は短い欠落の回復対象にせず、既存の完了回数だけ保持 |
| 「認識中」だけでは不足理由が分からない | 人体未検出、関節不足、低信頼、異常時刻、中断、復帰確認、準備完了、加算を内部理由と短い日本語表示で区別 |

155°/105°、信頼度0.50、最小反復時間0.25s、最大frame gap0.70sは据え置き。80ms/250msは合成セットで安全条件を評価した暫定値であり、人や撮影条件を使った校正値ではない。

移動中央値/ローパス、角度閾値変更、推論fps増加、Vision request再利用、ROI、3Dモデル、他SDKは導入しない。現在の再現不具合は時間・欠落・入力検証・座標尺度の修正で改善し、これら追加変更の実測根拠がないため。回転 `.up` と出力ミラー無効は従来通り。カメラ方向の変更には実映像とoverlayの一致確認が必要。

## 評価方法

`Tests/FitBOSSCoreTests/RecognitionFixtures.swift` はすべて手動で生成した角度/時刻/信頼度/欠落の合成入力。人から得た映像・座標ではない。

1. 最初に23試行のベースライン（MAE 0.217391、FP2/FN3）を保存し、評価コードをコミット `4d1652f` に分離した。
2. 追加回帰で12fpsの浮動小数点境界を再現し、画像縦横比の幾何学的検証を追加。最終26試行の**同一ハーネス・同一合成座標・同一時刻**を、凍結した変更前ソースと変更後へ再生した。評価セットの拡張を隠さない。
3. trialごとの絶対回数誤差 `abs(detected-truth)` の平均がMAE。biasは符号付き誤差の平均。正解は合成系列で定めた、下降後に最初に上閾値を満たす時刻。
4. 対応許容時間は事前に **0〜450ms**（未来方向のみ）と定め、検出イベントを未対応の正解イベントに一対一対応。早過ぎる/未対応検出はFP、残った正解はFN。許容時間を超える検出はFPとFNの両方になり得る。Precision/Recallはこのイベント対応から計算し、単純な回数差からは推定しない。
5. 判定遅延は対応できたTPの `countTime - truthTime`。遅延集計のTP数は修正前7、後12で異なる。両方で検出できた共通7イベントでも同じ中央値100ms・p95 300ms。条件の悪いFNを含まない指標なのでこれだけで性能改善を主張しない。
6. `swiftc -O` で同じハーネスをビルドし、200リプレイ、52,200 `process` 呼出しの壁時計時間を計測。フレーム生成は区間外。純粋な評価器の時間であり、Vision推論時間・カメラ→画面の遅延ではない。中央値/p95はnearest-rank。

### 再現コマンド

リポジトリ直下で実行。個人データを読み書きせず、Gitで管理された変更前の3ファイルだけをignored `.build` に展開する。

```bash
mkdir -p .build/recognition-baseline/Sources/FitBOSSCore
for file in PoseModels.swift ExerciseEvaluator.swift PushUpEvaluator.swift; do
  git show "0525d9ea37b19749a29f4b5e49808bc318c6b543:Sources/FitBOSSCore/$file" \
    > ".build/recognition-baseline/Sources/FitBOSSCore/$file"
done
bash Scripts/evaluate-recognition.sh .build/recognition-baseline --legacy-model > .build/before.json
bash Scripts/evaluate-recognition.sh > .build/after.json
swift test
bash Scripts/build-app.sh
FITBOSS_FIREBASE_ENABLED=1 swift build -c debug --product FitBOSSApp
```

`--legacy-model` は旧PoseFrameに縦横比フィールドがないためのコンパイル互換アダプタだけ。旧評価器へも同じ非正方形画像の正規化座標を渡す（旧撮影実装どおり比率情報は利用しない）。ハーネスは一時実行ファイルを終了時に削除。JSONも合成データの集計だけであり、実カメラの値は含まない。不要になれば生成したJSONだけを削除できる。

### 測定環境と全体結果

macOS 27.2 / Apple M5 / arm64 / Xcode 27.2 (27B52) / Apple Swift 6.4.2、2026-11-02。1回のローカル計測であり、処理時間の反復分布・有意差は検証していない。

| 指標（合成26試行） | 変更前 `0525d9e` | 変更後 |
| --- | ---: | ---: |
| 正解イベント | 12 | 12 |
| TP / FP / FN | 7 / 2 / 5 | 12 / 0 / 0 |
| MAE（回/試行） | 0.269231 | 0 |
| bias（回/試行） | -0.115385 | 0 |
| Precision | 0.777778 | 1 |
| Recall | 0.583333 | 1 |
| TPの判定遅延 中央値 / p95 | 100 / 300ms | 100 / 300ms |
| 評価器壁時計時間 中央値 / p95 | 0.125 / 0.167µs | 0.166 / 0.208µs |
| Vision推論時間 中央値 / p95、実fps、CPU | 未測定 | 未測定 |

評価器時間はこの計測で中央値0.041µs、p95 0.041µsの差があった。追加処理と測定ノイズを含む小さい差であり、「性能差なし」「実カメラで12fpsを達成」とは解釈しない。純粋な評価器の計測では時間基準の追加判定によるイベント遅延増加を認めなかった。

### シナリオ内訳（FP/FNはイベント対応）

| 合成シナリオ | 正解回数 | 前の検出 | 前FP/FN | 後の検出 | 後FP/FN |
| --- | ---: | ---: | ---: | ---: | ---: |
| normal-left | 1 | 1 | 0/0 | 1 | 0/0 |
| normal-right | 1 | 1 | 0/0 | 1 | 0/0 |
| twelve-fps-duration-boundary | 1 | 0 | 0/1 | 1 | 0/0 |
| landscape-16x9 | 1 | 0 | 0/1 | 1 | 0/0 |
| portrait-3x4 | 1 | 1 | 0/0 | 1 | 0/0 |
| slow | 1 | 1 | 0/0 | 1 | 0/0 |
| variable-cadence | 1 | 1 | 0/0 | 1 | 0/0 |
| two-reps | 2 | 2 | 0/0 | 2 | 0/0 |
| static-up | 0 | 0 | 0/0 | 0 | 0/0 |
| static-down | 0 | 0 | 0/0 | 0 | 0/0 |
| partial | 0 | 0 | 0/0 | 0 | 0/0 |
| near-threshold | 0 | 0 | 0/0 | 0 | 0/0 |
| single-down-spike | 0 | 0 | 0/0 | 0 | 0/0 |
| single-up-spike | 0 | 0 | 0/0 | 0 | 0/0 |
| dense-two-frame-noise | 0 | 1 | 1/0 | 0 | 0/0 |
| short-nil-same-arm | 1 | 0 | 0/1 | 1 | 0/0 |
| short-low-confidence | 1 | 0 | 0/1 | 1 | 0/0 |
| short-missing-wrist | 1 | 0 | 0/1 | 1 | 0/0 |
| loss-across-transition | 0 | 0 | 0/0 | 0 | 0/0 |
| different-arm-on-recovery | 0 | 0 | 0/0 | 0 | 0/0 |
| long-gap | 0 | 0 | 0/0 | 0 | 0/0 |
| nan-timestamp | 0 | 1 | 1/0 | 0 | 0/0 |
| duplicate-timestamp | 0 | 0 | 0/0 | 0 | 0/0 |
| reversed-timestamp | 0 | 0 | 0/0 | 0 | 0/0 |
| low-confidence-only | 0 | 0 | 0/0 | 0 | 0/0 |
| no-person | 0 | 0 | 0/0 | 0 | 0/0 |

左右腕、普通/遅い動き、固定12fps/変動間隔、静止、部分動作、単発ノイズ、短い欠落、端点を跨ぐ欠落、腕交代、長いgap、NaN/重複/逆行時刻、低信頼、人体未検出を含む。別の回帰テストでinf/負時刻、各主要関節の不正信頼度、不正/退化座標、無効設定、hard reset、再開、旧カメラ/旧revision、非正方形画像、純粋な回転/反射幾何を検証。回転の幾何テストは実機の画像方向を保証しない。

## 自動検証とUI確認

- 変更前：Swift **31件**、通常releaseアプリビルド成功。基準main CI [41392752952](https://github.com/asukamiyachi/FitBOSS/actions/runs/41392752952) も成功。
- 変更後：Swift **51件**（Core44＋App7、既存31件を含む）、通常releaseアプリビルド、公式Firebase/Google SDK debugコンパイル成功。app署名のローカル検証成功。
- `bash -n Scripts/evaluate-recognition.sh`、actionlint 1.7.12（変更workflow）、`git diff --check` 成功。
- 新たなCIステップは合成リプレイのみ。PR CIでSwift/通常ビルド、SDKコンパイル、内部DMG/署名/設定混入防止を検証する。リモートの最終HEAD・CI実行URL・結果はDraft PR本文を参照。バックエンド/Rulesを変更しないためEmulatorは変更判定に従ってskipとなる（実行成功ではない）。
- 内蔵カメラの起動、人体未検出の理由表示、0回、停止の状態変化をAXテキストで確認。映像/画像を取得せず、運動動作や手動正解回数は評価していない。カメラを停止し検証アプリを終了。既存署名済みオンラインアプリとローカル設定を保持した。

## 実機評価表（未記入を実測値で埋めない）

独立した観察者の正解イベントとアプリの計数時刻を同期して短い快適な試行で比較する。映像・画像・座標は保存せず、手動の正解時刻と合計だけを用いる。イベント時刻を用意できなければMAE/biasのみとし、Precision/Recallは算出しない。体調に応じて休息・中止し、試行数を埋めるための反復を要求しない。

| 条件 | 正解付き実機試行数 | 前後MAE/FP/FN/遅延 | 状態 |
| --- | ---: | --- | --- |
| 側面・普通/ゆっくり・適切な明るさ | 0 | 未測定 | 最優先 |
| 斜め／正面 | 0 | 未測定 | 2D投影の限界を分けて評価 |
| 内蔵／外付け／Continuity Camera | 0 | 未測定 | 内蔵の開始停止/未検出表示のみ確認 |
| 暗め／上半身のみ／肩肘手首の遮蔽 | 0 | 未測定 | 欠落回復時のFP増加を特に確認 |
| 停止/部分動作/途中開始/追跡復帰 | 0 | 未測定 | 合成のみ |
| カメラ切替／停止再開／スリープ | 0 | 未測定 | revision境界の合成と内蔵開始停止のみ |
| 820×540・サイズ変更・overlay回転/ミラー | 0 | 未測定 | 従来レイアウトポリシーテストのみ。映像位置合わせ未確認 |
| 無人・人体未検出の長時間FP、CPU/遅延 | 0 | 未測定 | UIの短い未検出/0回表示は精度試行ではない |

## セルフレビュー（P0〜P3）と残課題

- **P0：** 対象差分で秘密情報・録画・座標ログ・外部送信・破壊的保存処理を追加していない。既知の未解決P0なし。
- **P1：** NaN時刻の誤カウント、密集サンプルの誤確定、旧カメラ結果の混入を修正し回帰を追加。sample buffer自体の無効時刻も単なる欠落として扱わず、途中状態を破棄する通知を送る（通知時刻はhost時刻で、姿勢は含めない）。中断で欠落した遷移を作らず、カメラ境界では途中回数を常に破棄。対象差分で既知の未解決P1なし。これは実機精度の保証ではない。
- **P2：** 実人物の側面/斜め評価、Visionの関節検出精度、手前の腕の選択、複数人/人物交代、前面/回転カメラ、実カメラ切替・スリープは未検証。上腕の動きだけでも閾値を跨げる2D単腕方式であり、真の腕立て/フォームを保証できない。短い欠落でも端点を跨いだ動作は保守的に捨て、FNが残り得る。80ms/250msの実機校正と推論fps/CPU/遅延測定を公開前に行う。
- **P2：** 入力画像の縦横比補正は等方ピクセルを前提とする。特殊な非正方ピクセル/画像の事前変形は未検証。画像の回転/ミラー設定は根拠なく変更しない。
- **P3：** `.counted` は1観測分のテキスト表示。VoiceOverの読み上げ・十分な表示継続時間・820×540での理由文の視覚評価は未実施。先に診断理由を提供し、Issue #9の全体UI改善とは分離する。
- `ExerciseEvaluator` の公開契約、履歴保存形式と共有ストア、Google認証、Firebase Rules/Functions、オンラインキュー、ネオンデザイントークン、DMG/署名/公開フローは変更していない。全既存テストと関連CIで回帰を確認する。

## 一次資料

- [Apple: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images) — 正規化座標、関節の信頼度と画像座標への変換。
- [Apple: VNImageRequestHandler](https://developer.apple.com/documentation/vision/vnimagerequesthandler) — 画像方向は入力に対応させる。
- [Apple: AVCaptureSession.synchronizationClock](https://developer.apple.com/documentation/avfoundation/avcapturesession/synchronizationclock) — capture outputの時刻系（インストール済みApple SDKヘッダでも確認）。
- [Apple: CMSyncConvertTime](https://developer.apple.com/documentation/coremedia/cmsyncconverttime(_:from:to:)) — 時計間の時刻変換。
- [Apple: alwaysDiscardsLateVideoFrames](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes) — 遅いフレームの破棄とメモリ/遅延の関係。既存設定を維持。
