#!/bin/bash
set -e

echo "📄 Creating FCPXML destination from Xsend Motion template"
echo "=========================================================="

XSEND_DEST="/Library/Application Support/ProApps/Share Destinations/Xsend Motion.fcpxdest"
TEMP_XML="/tmp/xsend_fcpxml.xml"
OUTPUT_DEST="Moplug-SendToMotion-FCPXML.fcpxdest"

# Check if Xsend Motion exists
if [ ! -f "$XSEND_DEST" ]; then
    echo "❌ Xsend Motion.fcpxdest not found!"
    echo "This script requires Xsend Motion to be installed."
    exit 1
fi

echo ""
echo "1. Converting Xsend Motion to XML..."
plutil -convert xml1 -o "$TEMP_XML" "$XSEND_DEST"
echo "   ✓ Converted"

echo ""
echo "2. Modifying for FCPXML export..."

# Generate new UUID
NEW_UUID=$(uuidgen)

# Create modified version
# Change ONLY:
# - App name and path
# - UUID
# - Bundle ID
# DO NOT change "Export Media" type - keep it the same!

sed -e 's/Xsend Motion/Moplug Send Motion/g' \
    -e 's/Xsend%20Motion/Moplug%20SendToMotion/g' \
    -e 's|/Applications/Xsend%20Motion.app|/Applications/Moplug%20SendToMotion.app|g' \
    -e "s/98EBB0C8-D16C-484E-AA9D-129559A4C140/$NEW_UUID/g" \
    -e 's/com.automaticduck.Xsend-Motion/com.moplug.Moplug-On-Motion/g' \
    "$TEMP_XML" > /tmp/moplug_base.xml

# Add FCPXML inclusion flag
python3 << 'PYEOF'
import plistlib
import sys

try:
    with open('/tmp/moplug_base.xml', 'rb') as f:
        data = plistlib.load(f)

    objects = data.get('$objects', [])

    # Helper to find or add True
    def get_true_uid(objs):
        for i, obj in enumerate(objs):
            if obj is True:
                return i
        objs.append(True)
        return len(objs) - 1

    true_uid = get_true_uid(objects)
    true_ref = {'CF$UID': true_uid}

    # Find the destination object by name "Moplug Send Motion"
    name_uid = None
    for i, obj in enumerate(objects):
        if obj == "Moplug Send Motion":
            name_uid = i
            break

    found = False
    if name_uid is not None:
        for obj in objects:
            if isinstance(obj, dict) and 'name' in obj:
                # Check if name points to our string
                name_val = obj['name']
                if isinstance(name_val, dict) and name_val.get('CF$UID') == name_uid:
                    # Found the destination object
                    obj['includesFCPXML'] = true_ref
                    print("   ✓ Added includesFCPXML to destination object")
                    found = True
                    break
    
    if not found:
        print("   ⚠️ Warning: Could not find destination object to patch includesFCPXML")

    with open('/tmp/moplug_fcpxml.xml', 'wb') as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_XML)

except Exception as e:
    print(f"   ❌ Python script error: {e}")
    sys.exit(1)
PYEOF

echo "   ✓ Modified"

echo ""
echo "3. Converting to binary plist..."
plutil -convert binary1 -o "$OUTPUT_DEST" /tmp/moplug_fcpxml.xml
echo "   ✓ Converted"

echo ""
echo "4. Verifying..."
if [ -f "$OUTPUT_DEST" ]; then
    SIZE=$(stat -f%z "$OUTPUT_DEST")
    echo "   ✓ Created: $OUTPUT_DEST ($SIZE bytes)"

    plutil -lint "$OUTPUT_DEST" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✓ Valid plist"
    else
        echo "   ❌ Invalid plist!"
        exit 1
    fi
else
    echo "   ❌ Failed to create file!"
    exit 1
fi

# Clean up
rm "$TEMP_XML" /tmp/moplug_base.xml /tmp/moplug_fcpxml.xml

echo ""
echo "=========================================================="
echo "✅ Created: $OUTPUT_DEST"
echo ""
echo "UUID: $NEW_UUID"
echo "Type: Export Media (same as Xsend Motion)"
echo ""
echo "To install, run:"
echo "  ./complete_install_fcpxml.sh"
echo ""
