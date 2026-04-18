#!/bin/bash
# Run a bug test with its cfg.xml using RunTest.py
# Usage: ./run_test.sh BUG_XXX_test

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <test_name>"
    echo "Example: $0 BUG_002_test"
    exit 1
fi

TEST_NAME=$1

echo "Running test: $TEST_NAME..."

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSD_ROOT="$SCRIPT_DIR/.."
BUGTEST_DIR="$RSD_ROOT/Processor/Src/Verification/TestCode/Asm/BugTest"
TEST_SRC="$SCRIPT_DIR/tests/${TEST_NAME}.s"
CFG_SRC="$SCRIPT_DIR/tests/${TEST_NAME}_cfg.xml"
RUN_TEST="$RSD_ROOT/Processor/Tools/TestDriver/RunTest.py"

# Check test file exists
if [ ! -f "$TEST_SRC" ]; then
    echo "Error: Test file not found: $TEST_SRC"
    exit 1
fi

# Check cfg.xml exists
if [ ! -f "$CFG_SRC" ]; then
    echo "Error: cfg.xml not found: $CFG_SRC"
    echo "Run ./generate_cfg.sh ${TEST_NAME}.s first to generate it"
    exit 1
fi

# Copy test and cfg.xml to BugTest directory
echo "Copying test files to BugTest directory..."
cp "$TEST_SRC" "$BUGTEST_DIR/code.s"
cp "$CFG_SRC" "$BUGTEST_DIR/cfg.xml"

# Build the test
echo "Building test..."
cd "$RSD_ROOT/Processor/Src/Verification/TestCode/Asm"
make BugTest/code.hex

# Run test with RunTest.py
echo "Running test with RunTest.py..."
cd "$RSD_ROOT/Processor/Src"
python3 "$RUN_TEST" --test BugTest --simulator verilator

echo ""
echo "Test completed!"
