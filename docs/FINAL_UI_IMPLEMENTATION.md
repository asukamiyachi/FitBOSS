# 最終UI実装・検証記録（2026-11-03）

## 入力・スコープ

基準: ユーザー提供 `FitBOSS_Final_UI_Codex_Implementation_Spec_2026-11-03.md` と `FitBOSS 最終UIイメージ.png`。
要求されたZIPと残る2枚の参照画像は確認できず、提供Markdownの数値・状態契約を優先した。3枚全体との一致は未確認。

基点main: `6f6424bcddc82f8579d8b7c2e8c8af3a52dfe5ca`。Issue #9を照合。
PR #12 (`cc43fe5`) はDraft・未マージ。独立したmainベースのUI変更であり、PR #12を変更・取り込みしていない。
そのためこのUIブランチの種目は腕立てのみ。PR #12統合時はTrainingの種目Picker・保存不可条件・送信抑制を保持して競合を解消する必要がある。

## 変更と仕様の対応

| 範囲 | 実装 |
|---|---|
| Theme / Tokens | `BOSSPalette`にsemantic色を集約。Light/DarkとmacOS High Contrastの境界色。主要CTAの青紫グラデーションを濃色へ変更 |
| Settings / Root | System（初期値）/Light/DarkをAppStorageで保持。未知値はSystemへ。ページ単位のDark強制を除去 |
| Components | 全画面共通のpage/panel。Opaque surfaceで透明度低減に依存しない。押下・hover・focus・disabledの表示 |
| Home | Home初期選択。唯一の主要CTA、実履歴の継続・保存回数・直近記録。架空の対戦/バッジ統計を除去 |
| Training | 既存compact優先操作を保持。保存不可理由、起動/停止、カメラなしの文言。カメラ上の文字背景を不透明化。Reduce Motion時は数値transitionを停止 |
| Battle | SDK/認証/所属に応じた説明と実ナビゲーション。エラーを上部表示。「未デプロイ」の固定断言を除去。実ルーム/認可操作を保持 |
| 他画面 | native sidebar、標準Picker/TextFieldを保持し、共通背景とsemantic色へ追従 |

認識・CameraManager・Vision・Core・保存形式・OnlineService・ポーリング・Rules/Functions・署名/配布スクリプトは変更していない。人物写真、架空のスコア、ランキング、Pauseは追加していない。

## 自動検証

環境: Apple Silicon、Swift 6.4.2、Swift package tools 5.9 / Swift 5コンパイルモード、minimum macOS 14。

- `swift test`: 59件成功（Core 46 + App 13）。既存履歴共有・認識テストを含む。
- 新規テスト: appearanceの不正値fallback、オンライン前提条件、保存エラー優先、Light/Dark/High Contrast tokenの本文4.5:1・境界3:1以上。
- CTA: 両テーマのグラデーションを101地点ずつ・通常/押下で白文字4.5:1以上。無効状態はグレースケールで表現し文字のopacityを落とさない。
- `BOSSRenderTests`: Home/Battle、3サイズ、2外観の12パターンのImageRenderer生成成功。Sidebar 210pt・toolbar 52pt相当を差し引いたdetail。**見切れやnative controlのフォーカスを保証する画像比較テストではない**。
- `FITBOSS_BUILD_DIR=.build/final-ui ./Scripts/build-app.sh`: release offlineビルドとad-hoc署名検証成功。
- `FITBOSS_FIREBASE_ENABLED=1 swift build --scratch-path .build/experiments-online -c debug --product FitBOSSApp`: 成功。SDKコンパイルであり実ログイン/サーバー稼働検証ではない。
- `git diff --check`: 成功。
- Backend/CI/DMGコードは無変更。Emulator未実行（CIの条件判定によるskipは成功実行と扱わない）。

## 実アプリ観測

- Home起動、履歴ゼロ、Light/Dark即時切替、再起動後Dark保持、オフライン対戦の無効化・理由・ローカル導線をAXと画面で確認。
- 実画面: [Home Light](ui-evidence/home-light.png)、[Home Dark](ui-evidence/home-dark.png)、[Battle Dark](ui-evidence/battle-dark.png)。ユーザー履歴は空。カメラ映像・関節座標は撮影・保存していない。
- Trainingへ遷移後、カメラが「起動中」から進まず、実計測は未検証。画面離脱と検証アプリ終了を行った。原因は特定できておらず、既存カメラ実装は変更していない。
- Tab入力を試したがAX上のフォーカス移動は確認できなかった。キーボード操作の全経路成功とは扱わない。

## セルフレビューと残課題

- 修正済みP1: 明るい主要CTAの白文字コントラスト不足 → palette + gradient試験。
- 修正済みP2: ページ別Dark強制、初期アカウント画面、未実装統計の優先、サーバー状態の固定断言、保存不可理由の欠落。
- P0/P1の新規コード問題は見つかっていない。ただし以下のP2受入検証が残るため、**最終受入完了・マージ可能とは判定しない**。
- P2: 実ウィンドウの正確な3サイズ・サイドバー切替、全8画面/シート、VoiceOver読み上げ順、Tab/focus、OSのHigh Contrast/Reduce Motion/Reduce Transparency切替、2ウィンドウ間の外観反映は未検証。既存共有履歴の自動試験は成功。
- P2: Trainingの起動待ち原因、実カメラ許可/拒否/0台/切替/停止、実運動保存成功・失敗、オンライン認証・権限失効・ルーム状態の実画面は未検証。純粋表示条件と既存テストで代替できない。
- P3: InstrumentsのView更新/hitches測定未実施。計測なしの性能改善は主張しない。
- PR #12のCI `41465336565` はSwift/ビルド成功、SDKジョブはrunner未取得（macOS arm64容量不足）でキャンセル。UIとは独立した既存の制約。

mainへのマージ、デプロイ、料金変更、正式Releaseは行わない。

## 継続検証（2026-11-04）

- `0b3b32e` の [macOS CI](https://github.com/asukamiyachi/FitBOSS/actions/runs/41476969507) は初回runner未取得でキャンセル。失敗ジョブのみ再実行し、Swift tests/app build・Firebase SDK compile・backend contractが成功。Rules/Functions統合は変更範囲外でSKIPPED。
- 同SHAの [内部DMG CI](https://github.com/asukamiyachi/FitBOSS/actions/runs/41476969508) は成功。
- 実アプリでSidebar非表示→表示時のHome維持、履歴の空状態、未認証Team、構想のAchievements、Accountのローカル利用導線、System設定の表示を追加確認。
- P2表示問題を修正: Teamにオンライン利用不可/ログイン条件/処理中/エラーを追加。Achievementsの「未獲得」を「準備中」にし、実績判定が未実装であることを冒頭に明示。変更後の両画面をAXで再確認。
- この追加修正でもSwift 59件、offline app build、Firebase SDK有効debug compileが成功。新しいHEADのCIは別途PRチェックを参照（上記成功は`0b3b32e`に対する結果）。
- ローカル作業は`feat/final-native-ui`で継続し、区切りごとにDraft PR #13へ保存。クレジット残量の取得手段はないため、残量に依存した保存を行わない。

## PRレビュー（2026-11-04）

- 最新HEADの全変更範囲、レビューコメント、CI、mainの保護/rulesを確認。既存レビューコメントなし。mainへの必須レビュー・保護ルールなし。
- P2: `WorkoutCameraView.swift` の選択中種目が固定白文字のためLightで低コントラスト。カメラ起動/停止バッジも固定orangeが白surface上で読みにくい。primary/warning semantic色へ修正。準備中種目の背景もsurfaceへ統一。
- 修正後Swift 59件、offline release build/署名検証、Firebase SDK debug compileが成功。配色は既存の両テーマcontrastテスト対象tokenを使用。
- 再レビュー: Core/CameraManager/OnlineService/保存・認可・バックエンド・配布構成に差分なし。新規P0/P1および残存する既知のコード上のマージ阻害問題はなし。
- 既述のP2手動受入項目は未検証の制約として継続する。これは不具合を実証した項目ではない。今回のコード統合と最終UIの全項目受入は別の判定であり、カメラ起動・VoiceOver等が動作確認済みであるとは主張しない。
- ユーザーがレビュー/修正ループ後のマージを明示承認。修正HEADのCI成功と競合なしを再確認してから統合する。
