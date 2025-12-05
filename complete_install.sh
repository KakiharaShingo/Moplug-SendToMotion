#!/bin/bash
set -e

echo "🚀 Complete Installation of Moplug SendToMotion"
echo "================================================"

cd "/Users/shingo/Xcode_Local/git/Moplug SendToMotion"

# Step 1: Build
echo ""
echo "Step 1: Building app..."
xcodebuild -project "Moplug_SendToMotion.xcodeproj" \
    -scheme "Moplug SendToMotion" \
    -configuration Release \
    clean build 2>&1 | tail -5

# Find built app
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-*/Build/Products/Release -name "Moplug SendToMotion.app" -type d | head -1)

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Built app not found"
    exit 1
fi

echo "✓ Build complete: $BUILT_APP"

# Step 2: Fix NSPrincipalClass
echo ""
echo "Step 2: Fixing NSPrincipalClass..."
plutil -replace NSPrincipalClass -string "MoplugApplication" "$BUILT_APP/Contents/Info.plist"
echo "✓ NSPrincipalClass = MoplugApplication"

# Step 3: Add CFBundleSignature
echo ""
echo "Step 3: Adding CFBundleSignature..."
plutil -extract CFBundleSignature raw "$BUILT_APP/Contents/Info.plist" 2>/dev/null || \
    plutil -insert CFBundleSignature -string "MpSM" "$BUILT_APP/Contents/Info.plist"
echo "✓ CFBundleSignature = MpSM"

# Step 4: Re-sign
echo ""
echo "Step 4: Re-signing app..."
codesign --force --deep --sign - "$BUILT_APP" 2>&1 | head -1
echo "✓ Signed"

# Step 5: Remove extended attributes
echo ""
echo "Step 5: Removing extended attributes..."
xattr -rc "$BUILT_APP" 2>/dev/null || echo "  (none to remove)"
echo "✓ Done"

# Step 6: Install app
echo ""
echo "Step 6: Installing app to /Applications..."
rm -rf "/Applications/Moplug SendToMotion.app"
cp -R "$BUILT_APP" "/Applications/"
echo "✓ Installed"

# Step 7: Create .fcpxdest from Xsend template
echo ""
echo "Step 7: Creating .fcpxdest from Xsend Motion template..."
./create_from_xsend_template.sh 2>&1 | grep -E "✓|Created"

# Step 8: Install .fcpxdest
echo ""
echo "Step 8: Installing .fcpxdest file..."
if [ -f "Moplug-SendToMotion-v2.fcpxdest" ]; then
    sudo cp "Moplug-SendToMotion-v2.fcpxdest" "/Library/Application Support/ProApps/Share Destinations/"
    sudo chmod 644 "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion-v2.fcpxdest"
    sudo chown root:admin "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion-v2.fcpxdest"
    sudo xattr -c "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion-v2.fcpxdest" 2>/dev/null || echo "  (no attributes)"
    echo "✓ Installed: Moplug-SendToMotion-v2.fcpxdest"
else
    echo "❌ Error: .fcpxdest file not found"
    exit 1
fi

# Step 9: Remove old .fcpxdest files
echo ""
echo "Step 9: Removing old .fcpxdest files..."
sudo rm -f "/Library/Application Support/ProApps/Share Destinations/Moplug SendToMotion.fcpxdest" 2>/dev/null && echo "  ✓ Removed old file 1"
sudo rm -f "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest" 2>/dev/null && echo "  ✓ Removed old file 2"
sudo rm -f "/Library/Application Support/ProApps/Share Destinations/Moplug-Send-Motion v1.1.0.fcpxdest" 2>/dev/null && echo "  ✓ Removed old file 3"
echo "✓ Cleanup done"

# Step 10: Reset Launch Services
echo ""
echo "Step 10: Resetting Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
sleep 2
echo "✓ Launch Services reset"

# Step 11: Re-register apps
echo ""
echo "Step 11: Re-registering applications..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/Moplug SendToMotion.app"
echo "  ✓ Moplug SendToMotion"

for app in "/Applications/Final Cut Pro.app" "/Applications/Motion.app"; do
    if [ -d "$app" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$app"
        echo "  ✓ $(basename "$app")"
    fi
done

# Step 12: Verification
echo ""
echo "Step 12: Verification..."
echo "  App: $([ -d "/Applications/Moplug SendToMotion.app" ] && echo '✓' || echo '✗')"
echo "  .fcpxdest: $([ -f "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion-v2.fcpxdest" ] && echo '✓' || echo '✗')"
echo "  NSPrincipalClass: $(plutil -extract NSPrincipalClass raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist" 2>/dev/null)"
echo "  Log file will be at: ~/Library/Application Support/Moplug Send Motion/debug.log"

echo ""
echo "================================================"
echo "✅ Installation Complete!"
echo ""
echo "CRITICAL NEXT STEPS:"
echo ""
echo "1. QUIT Final Cut Pro if it's running (⌘+Q)"
echo "2. Wait 10 seconds"
echo "3. Launch Final Cut Pro"
echo "4. Open a project"
echo "5. Select a clip or timeline"
echo "6. Go to File > Share"
echo "7. Look for 'Moplug Send Motion'"
echo ""
echo "To check debug log:"
echo "  tail -f ~/Library/Application\ Support/Moplug\ Send\ Motion/debug.log"
echo ""
echo "To check system log:"
echo "  log show --predicate 'process == \"Moplug SendToMotion\" OR subsystem contains \"Moplug\"' --last 10m"
echo ""
echo "Installed files:"
ls -lh "/Library/Application Support/ProApps/Share Destinations/" | grep -i moplug || echo "  (no files found)"
