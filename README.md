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
./complete_install.sh
```

このスクリプトは以下を自動的に実行します：
1. アプリをビルド
2. Info.plistの設定を修正
3. /Applicationsにインストール
4. .fcpxdestファイルを作成・インストール
5. Launch Servicesに登録

## 使用方法

1. Final Cut Pro Xでプロジェクトを開く
2. タイムラインでクリップを選択
3. **File → Share → "Moplug Send Motion"** を選択
4. 保存場所を指定してMotionプロジェクトファイルを保存
5. 自動的にMotionが起動

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

- **complete_install.sh** - 完全インストールスクリプト
- **create_from_xsend_template.sh** - .fcpxdestファイル作成スクリプト
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
