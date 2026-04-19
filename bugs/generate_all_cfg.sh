#!/bin/bash
# Generate cfg.xml files for all bug tests
# This script runs each test on golden RTL and captures register values

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating cfg.xml for all bug tests..."
echo "========================================"
echo ""

# List of bug tests
TESTS=(
    "BUG_001_test.s"
    "BUG_002_test.s"
    "BUG_003_test.s"
    "BUG_004_test.s"
    "BUG_005_test.s"
    "BUG_006_test.s"
)

for test in "${TESTS[@]}"; do
    echo "Processing $test..."
    "$SCRIPT_DIR/generate_cfg.sh" "$test"
    echo ""
done

echo "========================================"
echo "All cfg.xml files generated successfully!"
echo "Files are in bugs/tests/ directory"
