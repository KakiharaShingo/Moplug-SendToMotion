#!/bin/bash
set -e

echo "🚀 Moplug Send Motion - Complete FCPXML Installation"
echo "====================================================="
echo ""

PROJECT_DIR="/Users/shingo/Xcode_Local/git/Moplug SendToMotion"
cd "$PROJECT_DIR"

# 1. Build the app
echo "1️⃣  Building Moplug SendToMotion.app..."
echo "----------------------------------------"
xcodebuild -project "Moplug_SendToMotion.xcodeproj" \
    -scheme "Moplug SendToMotion" \
    -configuration Release \
    clean build \
    | grep -E "Build succeeded|error:" || true

BUILT_APP="$HOME/Library/Developer/Xcode/DerivedData/Moplug_SendToMotion-ctcsgztwpdqtuyhatchrnlcklokg/Build/Products/Release/Moplug SendToMotion.app"

if [ ! -d "$BUILT_APP" ]; then
    # Try to find the actual DerivedData path
    DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Moplug_SendToMotion-*" -type d | head -1)
    if [ -n "$DERIVED_DATA" ]; then
        BUILT_APP="$DERIVED_DATA/Build/Products/Release/Moplug SendToMotion.app"
    fi
fi

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Build failed! App not found."
    exit 1
fi

echo "✓ Build succeeded"
echo ""

# 2. Fix NSPrincipalClass in Info.plist
echo "2️⃣  Fixing NSPrincipalClass..."
echo "----------------------------------------"
plutil -replace NSPrincipalClass -string "MoplugApplication" "$BUILT_APP/Contents/Info.plist"
echo "✓ NSPrincipalClass set to MoplugApplication"
echo ""

# 3. Sign the app with entitlements
echo "3️⃣  Code signing with entitlements..."
echo "----------------------------------------"
ENTITLEMENTS_FILE="$PROJECT_DIR/Moplug_SendToMotion/Moplug_SendToMotion.entitlements"
if [ -f "$ENTITLEMENTS_FILE" ]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$BUILT_APP"
    echo "✓ App signed with entitlements"
else
    codesign --force --deep --sign - "$BUILT_APP"
    echo "✓ App signed (no entitlements file found)"
fi
echo ""

# 4. Install to /Applications
echo "4️⃣  Installing to /Applications..."
echo "----------------------------------------"
if [ -d "/Applications/Moplug SendToMotion.app" ]; then
    echo "Removing old version..."
    sudo rm -rf "/Applications/Moplug SendToMotion.app"
fi

sudo cp -R "$BUILT_APP" "/Applications/"
echo "✓ Installed to /Applications"
echo ""

# 5. Create FCPXML destination
echo "5️⃣  Creating FCPXML destination..."
echo "----------------------------------------"
FCPXDEST_FILE="Moplug-SendToMotion-FCPXML.fcpxdest"

# Use the create script that clones Xsend Motion structure
./create_fcpxml_from_xsend.sh > /tmp/fcpxdest_creation.log 2>&1

if [ ! -f "$FCPXDEST_FILE" ]; then
    echo "❌ Failed to create fcpxdest file!"
    cat /tmp/fcpxdest_creation.log
    exit 1
fi

SIZE=$(stat -f%z "$FCPXDEST_FILE")
echo "✓ Created $FCPXDEST_FILE ($SIZE bytes)"
echo ""

# 6. Install fcpxdest
echo "6️⃣  Installing FCPXML destination..."
echo "----------------------------------------"
DEST_DIR="/Library/Application Support/ProApps/Share Destinations"

if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory..."
    sudo mkdir -p "$DEST_DIR"
fi

# Remove ALL old Moplug fcpxdest files
echo "Removing old Moplug destination files..."
sudo rm -f "$DEST_DIR"/Moplug*.fcpxdest
sudo rm -f "$DEST_DIR/Moplug-SendToMotion-v2.fcpxdest"
sudo rm -f "$DEST_DIR/Moplug-SendToMotion-FCPXML.fcpxdest"
sudo rm -f "$DEST_DIR/Moplug Send Motion.fcpxdest"
echo "✓ Removed old destination files"

sudo cp "$FCPXDEST_FILE" "$DEST_DIR/"
echo "✓ Installed to $DEST_DIR"
echo ""

# 7. Clear FCPX cache
echo "7️⃣  Clearing Final Cut Pro cache..."
echo "----------------------------------------"
FCPX_CACHE="$HOME/Library/Caches/com.apple.FinalCut/UserDestinations3.plist"
if [ -f "$FCPX_CACHE" ]; then
    rm "$FCPX_CACHE"
    echo "✓ Removed FCPX destination cache"
else
    echo "ℹ️  FCPX cache not found (OK)"
fi
echo ""

# 8. Reset Launch Services
echo "8️⃣  Resetting Launch Services..."
echo "----------------------------------------"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user
echo "✓ Launch Services reset"
echo ""

# 9. Verify installation
echo "9️⃣  Verifying installation..."
echo "----------------------------------------"
if [ -d "/Applications/Moplug SendToMotion.app" ]; then
    echo "✓ App installed: /Applications/Moplug SendToMotion.app"
fi

if [ -f "$DEST_DIR/Moplug-SendToMotion-FCPXML.fcpxdest" ]; then
    echo "✓ Destination installed: $DEST_DIR/Moplug-SendToMotion-FCPXML.fcpxdest"
fi

# Clean up
rm -f /tmp/fcpxdest_creation.log

echo ""
echo "====================================================="
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Restart Final Cut Pro"
echo "2. Select clips/timeline in FCPX"
echo "3. File → Share → \"Moplug Send Motion\""
echo "4. FCPXML will be exported and sent to the app"
echo ""
echo "Debug logs:"
echo "  tail -f ~/Library/Application\\ Support/Moplug\\ Send\\ Motion/debug.log"
echo ""
