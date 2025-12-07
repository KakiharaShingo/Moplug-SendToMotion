# Moplug SendToMotion

Final Cut Pro XのタイムラインをApple Motion 5のプロジェクトに変換するアプリケーションです。

## 機能

- Final Cut Pro Xの共有メニューから直接タイムラインを送信
- FCPXML形式の解析と変換
- Motionプロジェクトファイルの生成
- 元のメディアファイルを参照

## インストール方法

```bash
cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"
./complete_install_fcpxml.sh
```

このスクリプトは以下を自動的に実行します：
1. アプリをビルド
2. NSPrincipalClassを修正
3. コード署名
4. /Applicationsにインストール
5. FCPXML用の.fcpxdestファイルを作成
6. 古い.fcpxdestファイルを削除
7. 新しい.fcpxdestをインストール
8. FCPXキャッシュをクリア
9. Launch Servicesをリセット

## 使用方法

### 方法1: XMLエクスポート（推奨）
1. Final Cut Pro Xでプロジェクトを開く
2. タイムラインでクリップを選択
3. **File → Export → XML** を選択
4. .fcpxmlファイルを保存
5. .fcpxmlファイルをアプリにドラッグ&ドロップ、またはダブルクリック
6. 保存場所を指定してMotionプロジェクトファイル(.motn)を保存
7. 自動的にMotionが起動

### 方法2: アプリウィンドウにドラッグ&ドロップ
1. .fcpxmlファイルをMoplug SendToMotionアプリウィンドウにドラッグ
2. 保存場所を指定
3. Motionが起動

## デバッグ

デバッグログは以下に保存されます：
```bash
~/Library/Application Support/Moplug Send Motion/debug.log
```

リアルタイムで監視：
```bash
tail -f ~/Library/Application\ Support/Moplug\ Send\ Motion/debug.log
```

## 主要ファイル

- **complete_install_fcpxml.sh** - FCPXML用完全インストールスクリプト
- **create_fcpxml_from_xsend.sh** - .fcpxdestファイル作成スクリプト
- **diagnose.sh** - インストール状況の診断
- **INSTALL_GUIDE.md** - 詳細インストールガイド
- **TROUBLESHOOTING.md** - トラブルシューティングガイド

## 技術仕様

- **対応**: macOS 12.0以降、Final Cut Pro X 10.2以降、Motion 5
- **Apple Events**: ProVideo Asset Management suite対応
- **Bundle ID**: com.moplug.Moplug-On-Motion
- **NSPrincipalClass**: MoplugApplication

## ライセンス

Copyright © 2025 Moplug. All rights reserved.
