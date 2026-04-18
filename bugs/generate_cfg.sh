#!/bin/bash
# Generate cfg.xml for a bug test by running golden RTL simulation
# Usage: ./generate_cfg.sh BUG_XXX_test.s

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <test_file.s>"
    echo "Example: $0 BUG_002_test.s"
    exit 1
fi

TEST_FILE=$1
TEST_NAME=$(basename "$TEST_FILE" .s)

echo "Generating cfg.xml for $TEST_NAME..."

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSD_ROOT="$SCRIPT_DIR/.."
BUGTEST_DIR="$RSD_ROOT/Processor/Src/Verification/TestCode/Asm/BugTest"
TEST_SRC="$SCRIPT_DIR/tests/$TEST_FILE"

# Check test file exists
if [ ! -f "$TEST_SRC" ]; then
    echo "Error: Test file not found: $TEST_SRC"
    exit 1
fi

# Copy test to BugTest directory
echo "Copying test to BugTest directory..."
cp "$TEST_SRC" "$BUGTEST_DIR/code.s"

# Build the test
echo "Building test..."
cd "$RSD_ROOT/Processor/Src/Verification/TestCode/Asm"
make BugTest/code.hex > /dev/null 2>&1

# Run simulation
echo "Running simulation..."
cd "$RSD_ROOT/Processor/Src"
make -f Makefile.verilator.mk run > /dev/null 2>&1

# Extract register values from reg.out.hex
echo "Extracting register values..."
REG_FILE="$BUGTEST_DIR/reg.out.hex"

if [ ! -f "$REG_FILE" ]; then
    echo "Error: Register output file not found: $REG_FILE"
    exit 1
fi

# Parse reg.out.hex and generate cfg.xml
CFG_FILE="$BUGTEST_DIR/cfg.xml"

cat > "$CFG_FILE" << 'EOF'
<?xml version='1.0' encoding='utf-8'?>
<Config>
  <MaxTestCycles>5000</MaxTestCycles>
  <RegisterValues>
EOF

# Read register values (reg.out.hex format: one 32-bit hex value per line)
# R0-R31 followed by PC
REG_NUM=0
while IFS= read -r line; do
    # Remove any whitespace
    line=$(echo "$line" | tr -d '[:space:]')

    if [ -n "$line" ]; then
        if [ $REG_NUM -lt 32 ]; then
            printf "      <R%d>%s</R%d>\n" $REG_NUM "$line" $REG_NUM >> "$CFG_FILE"
        elif [ $REG_NUM -eq 32 ]; then
            printf "      <PC>%s</PC>\n" "$line" >> "$CFG_FILE"
        fi
        REG_NUM=$((REG_NUM + 1))
    fi
done < "$REG_FILE"

cat >> "$CFG_FILE" << 'EOF'
  </RegisterValues>
</Config>
EOF

echo "Generated: $CFG_FILE"
echo ""
echo "Register values:"
grep -E "<R[0-9]+>|<PC>" "$CFG_FILE" | head -10
echo "..."

# Copy cfg.xml to bugs/tests directory for reference
cp "$CFG_FILE" "$SCRIPT_DIR/tests/${TEST_NAME}_cfg.xml"
echo "Copied to: $SCRIPT_DIR/tests/${TEST_NAME}_cfg.xml"
