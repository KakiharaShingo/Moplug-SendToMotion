# Moplug SendToMotion - インストールガイド

## クイックインストール

```bash
cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"

# 1. 診断チェックを実行
./diagnose.sh

# 2. アプリをビルド・インストール
xcodebuild -project "Moplug_SendToMotion.xcodeproj" -scheme "Moplug SendToMotion" -configuration Release clean build

# 3. Info.plistを修正（重要！）
plutil -replace NSPrincipalClass -string "MoplugApplication" ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app/Contents/Info.plist

# 4. 再署名
codesign --force --deep --sign - ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app

# 5. インストール
rm -rf "/Applications/Moplug SendToMotion.app"
cp -R ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app /Applications/

# 6. .fcpxdestファイルをインストール
python3 create_fcpxdest.py
cp Moplug-SendToMotion.fcpxdest "/Library/Application Support/ProApps/Share Destinations/"

# 7. Launch Servicesに登録
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/Moplug SendToMotion.app"
```

## インストールの確認

```bash
./diagnose.sh
```

すべて✓マークが表示されればOKです。

## Final Cut Proで確認

1. **Final Cut Proを完全に終了**（⌘+Q）
2. 5秒待つ
3. **Final Cut Proを再起動**
4. **File > Share** メニューを開く
5. **"Moplug Send Motion"** が表示されているはずです

## トラブルシューティング

### FCPXのShareメニューに表示されない

#### 解決策1: Final Cut Proを完全に再起動

```bash
# FCPXのプロセスを完全に終了
killall "Final Cut Pro" 2>/dev/null

# 5秒待つ
sleep 5

# FCPXを再起動（手動で起動してください）
```

#### 解決策2: 古い.fcpxdestファイルを削除

複数の.fcpxdestファイルが存在すると競合する可能性があります：

```bash
./cleanup_old_fcpxdest.sh
```

または手動で：

```bash
# 古いファイルを削除
rm "/Library/Application Support/ProApps/Share Destinations/Moplug SendToMotion.fcpxdest"
rm "/Library/Application Support/ProApps/Share Destinations/Moplug-Send-Motion v1.1.0.fcpxdest"

# 最新版のみを残す
ls -la "/Library/Application Support/ProApps/Share Destinations/" | grep -i moplug
```

#### 解決策3: Launch Servicesデータベースをリセット

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# アプリを再登録
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/Moplug SendToMotion.app"
```

#### 解決策4: NSPrincipalClassの確認

```bash
plutil -extract NSPrincipalClass raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist"
```

**期待される出力**: `MoplugApplication`

もし `NSApplication` と表示された場合は、手動で修正：

```bash
plutil -replace NSPrincipalClass -string "MoplugApplication" "/Applications/Moplug SendToMotion.app/Contents/Info.plist"
codesign --force --deep --sign - "/Applications/Moplug SendToMotion.app"
```

#### 解決策5: FCPXのキャッシュをクリア

```bash
# FCPXのpreferencesをバックアップ
cp -R ~/Library/Preferences/com.apple.FinalCut.plist ~/Desktop/FinalCut.plist.backup

# FCPXを終了
killall "Final Cut Pro" 2>/dev/null

# キャッシュをクリア（オプション）
# 注意: これによりFCPXの設定がリセットされる可能性があります
# rm ~/Library/Preferences/com.apple.FinalCut.plist

# FCPXを再起動
```

### Apple Eventが受け取れない

```bash
# ログを確認
log show --predicate 'subsystem contains "Moplug"' --last 1h

# アプリが正しく設定されているか確認
./diagnose.sh
```

### ファイルをドラッグ&ドロップしても反応しない

FCPXMLファイルを直接アプリで開いてテスト：

```bash
open -a "/Applications/Moplug SendToMotion.app" /path/to/test.fcpxml
```

## 完全な再インストール

すべてをクリーンアップして再インストール：

```bash
# 1. すべてのMoplug関連ファイルを削除
rm -rf "/Applications/Moplug SendToMotion.app"
rm "/Library/Application Support/ProApps/Share Destinations/Moplug"*.fcpxdest

# 2. 最初からインストール
cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"
xcodebuild -project "Moplug_SendToMotion.xcodeproj" -scheme "Moplug SendToMotion" -configuration Release clean build

# 3. Info.plistを修正
plutil -replace NSPrincipalClass -string "MoplugApplication" ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app/Contents/Info.plist

# 4. 再署名とインストール
codesign --force --deep --sign - ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app
cp -R ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release/Moplug\ SendToMotion.app /Applications/

# 5. .fcpxdestを作成・インストール
python3 create_fcpxdest.py
cp Moplug-SendToMotion.fcpxdest "/Library/Application Support/ProApps/Share Destinations/"

# 6. Launch Servicesに登録
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/Moplug SendToMotion.app"

# 7. FCPXを再起動
killall "Final Cut Pro" 2>/dev/null
echo "Final Cut Proを手動で起動してください"
```

## 重要なポイント

1. **NSPrincipalClass**: `MoplugApplication`である必要があります（`NSApplication`ではない）
2. **OSAScriptingDefinition.sdef**: アプリのResourcesフォルダに含まれている必要があります
3. **アプリパス**: .fcpxdestファイル内のパスと実際のアプリの場所が一致する必要があります
4. **FCPXの再起動**: インストール後は必ずFCPXを完全に終了して再起動してください

## 成功の確認

```bash
./diagnose.sh
```

すべて✓マークが表示され、FCPXのFile > Shareメニューに"Moplug Send Motion"が表示されれば成功です！
