## FCPX共有メニューに「Moplug Send Motion」が表示されない場合のトラブルシューティング

### 手順1: 診断チェック

まず、現在の状態を確認します：

```bash
cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"
./diagnose.sh
```

すべて✓マークが表示されているか確認してください。

### 手順2: 基本的な解決策

#### A. FCPXの完全再起動

```bash
# FCPXを完全に終了
killall "Final Cut Pro" 2>/dev/null

# 10秒待つ
sleep 10

# 手動でFCPXを起動
```

これで表示されない場合は次へ。

#### B. .fcpxdestファイルの修正

```bash
./fix_fcpx_destination.sh
```

このスクリプトは：
- 拡張属性を削除
- 古い.fcpxdestファイルを削除
- 新しい.fcpxdestファイルを作成
- 正しい権限を設定
- Launch Servicesに再登録

実行後、FCPXを再起動してください。

#### C. FCPXキャッシュのリセット

```bash
./reset_fcpx_cache.sh
```

このスクリプトは：
- FCPXのキャッシュをクリア
- Launch Servicesデータベースをリセット
- すべてのProAppsを再登録

実行後、FCPXを再起動してください。

### 手順3: 手動での確認・修正

上記でも解決しない場合、以下を手動で確認：

#### 1. アプリの設定確認

```bash
# NSPrincipalClassを確認
plutil -extract NSPrincipalClass raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist"
# 期待値: MoplugApplication

# NSAppleScriptEnabledを確認
plutil -extract NSAppleScriptEnabled raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist"
# 期待値: true

# .sdefファイルの存在確認
ls -la "/Applications/Moplug SendToMotion.app/Contents/Resources/OSAScriptingDefinition.sdef"
# ファイルが存在するはず
```

もし`NSPrincipalClass`が`NSApplication`の場合：

```bash
plutil -replace NSPrincipalClass -string "MoplugApplication" "/Applications/Moplug SendToMotion.app/Contents/Info.plist"
codesign --force --deep --sign - "/Applications/Moplug SendToMotion.app"
```

#### 2. .fcpxdestファイルの確認

```bash
# ファイルの存在確認
ls -la "/Library/Application Support/ProApps/Share Destinations/" | grep Moplug

# アプリパスの確認
plutil -convert xml1 -o - "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest" | grep appName

# 期待値: appName="/Applications/Moplug%20SendToMotion.app"
```

#### 3. 拡張属性の確認と削除

```bash
# 拡張属性の確認
xattr "/Applications/Moplug SendToMotion.app"
xattr "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"

# もし属性がある場合は削除
sudo xattr -rc "/Applications/Moplug SendToMotion.app"
sudo xattr -c "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"
```

#### 4. 古い重複ファイルの削除

```bash
# 古いバージョンを削除
sudo rm "/Library/Application Support/ProApps/Share Destinations/Moplug SendToMotion.fcpxdest"
sudo rm "/Library/Application Support/ProApps/Share Destinations/Moplug-Send-Motion v1.1.0.fcpxdest"

# 最新版のみが残っているか確認
ls -la "/Library/Application Support/ProApps/Share Destinations/" | grep -i moplug
```

### 手順4: 完全リセット

上記すべてを試しても表示されない場合：

#### 方法A: システム再起動

Launch Servicesの変更が反映されるには、システム再起動が必要な場合があります。

```bash
# すべてのスクリプトを実行後
sudo shutdown -r now
```

#### 方法B: 完全再インストール

```bash
# 1. すべて削除
sudo rm -rf "/Applications/Moplug SendToMotion.app"
sudo rm "/Library/Application Support/ProApps/Share Destinations/Moplug"*.fcpxdest

# 2. ビルド
cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"
xcodebuild -project "Moplug_SendToMotion.xcodeproj" -scheme "Moplug SendToMotion" -configuration Release clean build

# 3. Info.plist修正
BUILD_APP=$(find ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release -name "Moplug SendToMotion.app" -type d | head -1)
plutil -replace NSPrincipalClass -string "MoplugApplication" "$BUILD_APP/Contents/Info.plist"

# 4. 署名とインストール
codesign --force --deep --sign - "$BUILD_APP"
sudo cp -R "$BUILD_APP" "/Applications/"

# 5. 拡張属性削除
sudo xattr -rc "/Applications/Moplug SendToMotion.app"

# 6. .fcpxdest作成・インストール
python3 create_fcpxdest.py
sudo cp Moplug-SendToMotion.fcpxdest "/Library/Application Support/ProApps/Share Destinations/"
sudo xattr -c "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"
sudo chmod 644 "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"
sudo chown root:admin "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"

# 7. Launch Servicesリセット
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/Moplug SendToMotion.app"

# 8. システム再起動
sudo shutdown -r now
```

### 既知の問題と解決策

#### 問題1: "Moplug Send Motion"が灰色で選択できない

**原因**: FCPXでクリップまたはタイムラインが選択されていない

**解決策**: タイムラインでクリップを選択してから、File > Share を開く

#### 問題2: 選択すると何も起こらない

**原因**: Apple Eventハンドラーが正しく登録されていない

**解決策**:
```bash
# ログを確認
log show --predicate 'subsystem contains "Moplug" OR process == "Moplug SendToMotion"' --last 10m

# AppDelegateの確認
grep -A5 "handleOpenDocumentEvent" "/Applications/Moplug SendToMotion.app/Contents/MacOS/Moplug SendToMotion"
```

#### 問題3: Xsend Motionは表示されるがMoplugは表示されない

**原因**: .fcpxdestファイルの構造に問題がある可能性

**解決策**: Xsend Motionのファイルと比較
```bash
plutil -convert xml1 -o /tmp/xsend.xml "/Library/Application Support/ProApps/Share Destinations/Xsend Motion.fcpxdest"
plutil -convert xml1 -o /tmp/moplug.xml "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest"
diff /tmp/xsend.xml /tmp/moplug.xml
```

### デバッグ情報の収集

サポートが必要な場合、以下の情報を収集してください：

```bash
# 診断情報
./diagnose.sh > diagnostic_output.txt

# システム情報
sw_vers >> diagnostic_output.txt
echo "---" >> diagnostic_output.txt

# FCPXバージョン
/Applications/Final\ Cut\ Pro.app/Contents/MacOS/Final\ Cut\ Pro --version 2>&1 >> diagnostic_output.txt || echo "FCP version check failed" >> diagnostic_output.txt

# ファイル一覧
echo "=== Share Destinations ===" >> diagnostic_output.txt
ls -la "/Library/Application Support/ProApps/Share Destinations/" >> diagnostic_output.txt

# App Info.plist
echo "=== App Info.plist ===" >> diagnostic_output.txt
plutil -p "/Applications/Moplug SendToMotion.app/Contents/Info.plist" | grep -E "Principal|AppleScript|OSAScripting" >> diagnostic_output.txt

cat diagnostic_output.txt
```

### 最終手段

すべてを試してもダメな場合：

1. **macOS自体の問題**: システムの整合性を確認
   ```bash
   sudo /usr/libexec/repair_packages --verify --standard-pkgs --volume /
   ```

2. **FCPXの再インストール**: App Storeから再インストール

3. **別のアプローチ**: ドラッグ&ドロップでFCPXMLファイルをアプリに渡す方法を使用
