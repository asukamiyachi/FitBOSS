# FitBOSS

Macで利用できる、カメラを使った腕立て伏せ計測アプリの試作版です。

## 動作環境

- macOS 14以降
- XcodeまたはCommand Line Tools（Swift 5.9以降）
- 内蔵カメラ、USBカメラ、またはContinuity Camera

## インストールと起動

公開版のダウンロードは準備中です。現在はMac上でソースからビルドして起動します。

```sh
git clone https://github.com/asukamiyachi/FitBOSS.git
cd FitBOSS
./Scripts/build-app.sh
open .build/FitBOSS.app
```

初回利用時はカメラへのアクセスを許可してください。許可しなかった場合は「システム設定 → プライバシーとセキュリティ → カメラ」から変更できます。

この手順で作成するアプリはローカル練習用です。Googleログインとオンライン機能の利用には別途設定が必要です。
