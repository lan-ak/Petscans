#!/bin/bash

# App Store screenshot pipeline for PetScans.
# Usage: ./Scripts/run_screenshots.sh
#
# Two passes per device size:
#   1. PetScansUITests/ScreenshotTests stages each screen and writes a raw capture
#      plus, for the shots that have one, a `<shot>.floats.json` naming the card the
#      framing step should lift out. Raws land in Screenshots/<size>-inch/.
#   2. Scripts/compose_marketing_shots.py frames those into Screenshots/<size>-framed/,
#      which is what gets uploaded.
#
# The tests write through $PROJECT_DIR. xcodebuild does not pass build settings into
# the test runner's environment, so it has to arrive as TEST_RUNNER_PROJECT_DIR —
# passing PROJECT_DIR= writes the captures to /Screenshots and silently drops them.
#
# Prerequisites: the simulators named in DEVICES below. Create a missing one with
#   xcrun simctl create "iPhone 14 Plus" \
#     com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus \
#     com.apple.CoreSimulator.SimRuntime.iOS-26-5

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="PetScans.xcodeproj"
SCHEME="PetScans"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"

# Device, App Store size class, and the pixel dimensions that size expects.
declare -a DEVICES=("iPhone 17 Pro Max" "iPhone 14 Plus")
declare -a SIZES=("6.9" "6.5")
declare -a WIDTHS=(1320 1284)
declare -a HEIGHTS=(2868 2778)

# The App Store shot list. Other tests in the suite (onboarding, smoke) are not part
# of the listing and are not run here.
declare -a SHOTS=(
    test01_HeroScore
    test02_UnsafeIngredients
    test03_AllergenAlert
    test04_IngredientDetail
    test05_Library
    test06_Sources
)

ONLY_TESTING=()
for shot in "${SHOTS[@]}"; do
    ONLY_TESTING+=("-only-testing:PetScansUITests/ScreenshotTests/$shot")
done

echo "Project: $PROJECT_DIR"
echo "Output:  $OUTPUT_DIR"

ALL_PASSED=true

for i in "${!DEVICES[@]}"; do
    DEVICE="${DEVICES[$i]}"
    SIZE="${SIZES[$i]}"
    W="${WIDTHS[$i]}"
    H="${HEIGHTS[$i]}"

    RAW_DIR="$OUTPUT_DIR/${SIZE}-inch"
    FRAMED_DIR="$OUTPUT_DIR/${SIZE}-framed"

    echo ""
    echo "=========================================="
    echo "$DEVICE — ${SIZE}\" (${W}x${H})"
    echo "=========================================="

    rm -rf "$RAW_DIR" "$FRAMED_DIR"
    mkdir -p "$RAW_DIR" "$FRAMED_DIR"
    rm -f "$OUTPUT_DIR"/*.png "$OUTPUT_DIR"/*.floats.json

    set +e
    TEST_RUNNER_PROJECT_DIR="$PROJECT_DIR" xcodebuild test \
        -project "$PROJECT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        "${ONLY_TESTING[@]}" \
        > "$RAW_DIR/build.log" 2>&1
    BUILD_RESULT=$?
    set -e

    if [ $BUILD_RESULT -ne 0 ]; then
        echo "FAILED — see $RAW_DIR/build.log"
        ALL_PASSED=false
        continue
    fi

    # The tests write flat into Screenshots/; sort them into the size's folder.
    mv "$OUTPUT_DIR"/*.png "$RAW_DIR/"
    mv "$OUTPUT_DIR"/*.floats.json "$RAW_DIR/"

    ACTUAL="$(sips -g pixelWidth "$RAW_DIR/01_HeroScore.png" | awk '/pixelWidth/ {print $2}')x$(sips -g pixelHeight "$RAW_DIR/01_HeroScore.png" | awk '/pixelHeight/ {print $2}')"
    if [ "$ACTUAL" != "${W}x${H}" ]; then
        echo "FAILED — $DEVICE captured at $ACTUAL, expected ${W}x${H}"
        ALL_PASSED=false
        continue
    fi

    python3 "$PROJECT_DIR/Scripts/compose_marketing_shots.py" "$RAW_DIR" "$FRAMED_DIR" "$W" "$H"
    echo "Framed -> $FRAMED_DIR"
done

echo ""
if [ "$ALL_PASSED" = true ]; then
    echo "All sizes complete. Upload from the *-framed folders."
else
    echo "Some sizes failed. Check the build logs above."
    exit 1
fi
