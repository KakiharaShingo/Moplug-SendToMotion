#!/bin/bash

echo "🔍 Moplug SendToMotion - Diagnostic Check"
echo "=========================================="

# Check app installation
echo ""
echo "1. Checking app installation..."
if [ -d "/Applications/Moplug SendToMotion.app" ]; then
    echo "   ✓ App found at /Applications/Moplug SendToMotion.app"

    # Check Info.plist
    echo ""
    echo "2. Checking Info.plist configuration..."
    echo "   NSPrincipalClass: $(plutil -extract NSPrincipalClass raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist" 2>/dev/null || echo 'NOT FOUND')"
    echo "   NSAppleScriptEnabled: $(plutil -extract NSAppleScriptEnabled raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist" 2>/dev/null || echo 'NOT FOUND')"
    echo "   OSAScriptingDefinition: $(plutil -extract OSAScriptingDefinition raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist" 2>/dev/null || echo 'NOT FOUND')"
    echo "   CFBundleIdentifier: $(plutil -extract CFBundleIdentifier raw "/Applications/Moplug SendToMotion.app/Contents/Info.plist" 2>/dev/null || echo 'NOT FOUND')"

    # Check sdef file
    echo ""
    echo "3. Checking OSAScriptingDefinition.sdef..."
    if [ -f "/Applications/Moplug SendToMotion.app/Contents/Resources/OSAScriptingDefinition.sdef" ]; then
        echo "   ✓ OSAScriptingDefinition.sdef found"
    else
        echo "   ✗ OSAScriptingDefinition.sdef NOT FOUND"
    fi
else
    echo "   ✗ App NOT FOUND at /Applications/Moplug SendToMotion.app"
fi

# Check .fcpxdest file
echo ""
echo "4. Checking .fcpxdest file..."
if [ -f "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest" ]; then
    echo "   ✓ .fcpxdest found"

    # Extract and check app path
    APP_PATH=$(plutil -convert xml1 -o - "/Library/Application Support/ProApps/Share Destinations/Moplug-SendToMotion.fcpxdest" 2>/dev/null | grep -o 'appName="[^"]*"' | cut -d'"' -f2 | sed 's/%20/ /g')
    echo "   App path in .fcpxdest: $APP_PATH"

    if [ -d "$APP_PATH" ]; then
        echo "   ✓ App path is valid"
    else
        echo "   ✗ App path does NOT exist!"
    fi
else
    echo "   ✗ .fcpxdest NOT FOUND"
fi

# Check other share destinations for comparison
echo ""
echo "5. Other installed share destinations:"
ls -1 "/Library/Application Support/ProApps/Share Destinations/" 2>/dev/null | grep -v "^$"

# Check Launch Services registration
echo ""
echo "6. Checking Launch Services registration..."
lsregister -dump | grep -A5 "Moplug SendToMotion" | head -10

echo ""
echo "=========================================="
echo "If Final Cut Pro is not showing 'Moplug Send Motion':"
echo ""
echo "1. Completely quit Final Cut Pro (⌘+Q)"
echo "2. Wait 5 seconds"
echo "3. Restart Final Cut Pro"
echo "4. Check File > Share menu"
echo ""
echo "If still not visible:"
echo "  - Try resetting Launch Services database:"
echo "    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"
echo ""
