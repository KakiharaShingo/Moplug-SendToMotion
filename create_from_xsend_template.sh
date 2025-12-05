#!/bin/bash
set -e

echo "📄 Creating .fcpxdest from Xsend Motion template"
echo "=================================================="

XSEND_DEST="/Library/Application Support/ProApps/Share Destinations/Xsend Motion.fcpxdest"
TEMP_XML="/tmp/xsend_template.xml"
OUTPUT_XML="/tmp/moplug_modified.xml"
OUTPUT_DEST="Moplug-SendToMotion-v2.fcpxdest"

# Check if Xsend Motion exists
if [ ! -f "$XSEND_DEST" ]; then
    echo "❌ Xsend Motion.fcpxdest not found!"
    echo "Cannot create template without Xsend Motion installed."
    exit 1
fi

echo ""
echo "1. Converting Xsend Motion.fcpxdest to XML..."
plutil -convert xml1 -o "$TEMP_XML" "$XSEND_DEST"
echo "   ✓ Converted"

echo ""
echo "2. Creating modified version for Moplug..."

# Replace all occurrences of "Xsend Motion" with "Moplug Send Motion"
# Replace app path
# Generate new UUID
NEW_UUID=$(uuidgen)

sed -e 's/Xsend Motion/Moplug Send Motion/g' \
    -e 's/Xsend%20Motion/Moplug%20SendToMotion/g' \
    -e 's|/Applications/Xsend%20Motion.app|/Applications/Moplug%20SendToMotion.app|g' \
    -e "s/98EBB0C8-D16C-484E-AA9D-129559A4C140/$NEW_UUID/g" \
    -e 's/com.automaticduck.Xsend-Motion/com.moplug.Moplug-On-Motion/g' \
    "$TEMP_XML" > "$OUTPUT_XML"

echo "   ✓ Modified"

echo ""
echo "3. Converting back to binary plist..."
plutil -convert binary1 -o "$OUTPUT_DEST" "$OUTPUT_XML"
echo "   ✓ Converted to binary"

echo ""
echo "4. Verifying the file..."
if [ -f "$OUTPUT_DEST" ]; then
    SIZE=$(stat -f%z "$OUTPUT_DEST")
    echo "   ✓ File created: $OUTPUT_DEST ($SIZE bytes)"

    # Verify it's a valid plist
    plutil -lint "$OUTPUT_DEST" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✓ Valid binary plist"
    else
        echo "   ❌ Invalid plist format!"
        exit 1
    fi
else
    echo "   ❌ File creation failed!"
    exit 1
fi

# Show what we changed
echo ""
echo "5. Changes made:"
echo "   UUID: $NEW_UUID"
echo "   Name: Moplug Send Motion"
echo "   App Path: /Applications/Moplug%20SendToMotion.app"

# Clean up
rm "$TEMP_XML" "$OUTPUT_XML"

echo ""
echo "=================================================="
echo "✅ Created: $OUTPUT_DEST"
echo ""
echo "To install:"
echo "  sudo cp '$OUTPUT_DEST' '/Library/Application Support/ProApps/Share Destinations/'"
echo ""
echo "Then restart Final Cut Pro"
