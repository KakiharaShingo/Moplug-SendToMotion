#!/bin/bash
set -e

echo "📄 Creating simple FCPXML destination"
echo "======================================"

OUTPUT_DEST="Moplug-SendToMotion-FCPXML.fcpxdest"
NEW_UUID=$(uuidgen)

# Create a simpler structure for XML export (not media export)
cat > /tmp/create_simple_fcpxml.py << 'PYEOF'
import plistlib
import sys

uuid_str = sys.argv[1]
output_file = sys.argv[2]

# Simple FCPXML export destination (no video settings needed)
destination = {
    "name": "Moplug Send Motion",
    "type": "Send to App",  # Changed from "Export XML"
    "uuid": uuid_str,
    "applicationPath": "/Applications/Moplug SendToMotion.app",
    "bundleIdentifier": "com.moplug.Moplug-On-Motion",
    "formatSpecification": "FCPXML 1.11"
}

with open(output_file, 'wb') as f:
    plistlib.dump(destination, f, fmt=plistlib.FMT_BINARY)

print(f"Created {output_file}")
PYEOF

python3 /tmp/create_simple_fcpxml.py "$NEW_UUID" "$OUTPUT_DEST"

if [ -f "$OUTPUT_DEST" ]; then
    SIZE=$(stat -f%z "$OUTPUT_DEST")
    echo "✓ Created: $OUTPUT_DEST ($SIZE bytes)"
    echo "✓ UUID: $NEW_UUID"
else
    echo "❌ Failed!"
    exit 1
fi

# Clean up
rm /tmp/create_simple_fcpxml.py

echo ""
echo "======================================"
echo "✅ Done"
