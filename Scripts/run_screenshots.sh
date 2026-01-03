#!/bin/bash

# App Store Screenshot Automation Script for PetScans
# Usage: ./Scripts/run_screenshots.sh
#
# Prerequisites:
# 1. Add UI Test target to Xcode project (File > New > Target > UI Testing Bundle)
#    - Name: PetScansUITests
#    - Host Application: PetScans
# 2. Add PetScansUITests/ScreenshotTests.swift to the new target
# 3. Ensure simulators are available (Xcode > Window > Devices and Simulators)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="PetScans.xcodeproj"
SCHEME="PetScans"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"

# Device configurations for App Store requirements
declare -a DEVICES=(
    "iPhone 16 Pro Max"
    "iPhone 15 Plus"
    "iPhone 11 Pro Max"
)

declare -a SIZES=(
    "6.9"
    "6.7"
    "6.5"
)

echo "============================================"
echo "PetScans App Store Screenshot Generator"
echo "============================================"
echo ""
echo "Project: $PROJECT_DIR"
echo "Output:  $OUTPUT_DIR"
echo ""

# Clean output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Track overall success
ALL_PASSED=true

for i in "${!DEVICES[@]}"; do
    DEVICE="${DEVICES[$i]}"
    SIZE="${SIZES[$i]}"

    echo ""
    echo "=========================================="
    echo "Device: $DEVICE ($SIZE inch)"
    echo "=========================================="

    # Create device-specific output folder
    DEVICE_DIR="$OUTPUT_DIR/${SIZE}-inch"
    mkdir -p "$DEVICE_DIR"

    # Run UI tests on this device
    set +e
    xcodebuild test \
        -project "$PROJECT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -only-testing:PetScansUITests/ScreenshotTests \
        -resultBundlePath "$DEVICE_DIR/TestResults.xcresult" \
        PROJECT_DIR="$PROJECT_DIR" \
        2>&1 | tee "$DEVICE_DIR/build.log"

    BUILD_RESULT=${PIPESTATUS[0]}
    set -e

    if [ $BUILD_RESULT -eq 0 ]; then
        echo "✅ Tests passed for $DEVICE"

        # Extract screenshots from test results
        if [ -d "$DEVICE_DIR/TestResults.xcresult" ]; then
            echo "Extracting screenshots from test results..."

            # List attachments in the xcresult bundle
            xcrun xcresulttool get --path "$DEVICE_DIR/TestResults.xcresult" \
                --format json 2>/dev/null > "$DEVICE_DIR/results.json" || true

            # Screenshots are typically in Attachments folder within xcresult
            ATTACHMENTS_DIR="$DEVICE_DIR/TestResults.xcresult"

            # Use xcresulttool to export attachments
            # Note: Screenshots are attached to test cases and can be found in the xcresult
            echo "Screenshots are available in: $DEVICE_DIR/TestResults.xcresult"
            echo "Open in Xcode: open \"$DEVICE_DIR/TestResults.xcresult\""
        fi
    else
        echo "❌ Tests failed for $DEVICE"
        echo "Check build log: $DEVICE_DIR/build.log"
        ALL_PASSED=false
    fi
done

echo ""
echo "=========================================="
echo "Screenshot Generation Complete"
echo "=========================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""

if [ "$ALL_PASSED" = true ]; then
    echo "✅ All devices completed successfully!"
    echo ""
    echo "To view screenshots:"
    echo "  1. Open each .xcresult in Xcode"
    echo "  2. Navigate to the test results"
    echo "  3. Expand test cases to see attached screenshots"
    echo ""
    echo "Or find PNG files saved by the tests in $OUTPUT_DIR"
else
    echo "⚠️  Some devices had failures. Check the build logs."
    exit 1
fi
