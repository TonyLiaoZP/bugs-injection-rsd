#!/bin/bash
# Run all bug tests with RunTest.py
# Usage: ./run_all_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all bug tests..."
echo "========================================"
echo ""

# List of bug tests
TESTS=(
    "BUG_001_test"
    "BUG_002_test"
    "BUG_003_test"
    "BUG_004_test"
    "BUG_005_test"
    "BUG_006_test"
)

PASSED=0
FAILED=0
FAILED_TESTS=()

for test in "${TESTS[@]}"; do
    echo "Running $test..."
    if "$SCRIPT_DIR/run_test.sh" "$test"; then
        echo "✓ $test PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "✗ $test FAILED"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("$test")
    fi
    echo ""
done

echo "========================================"
echo "Test Results:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    exit 1
fi

echo ""
echo "All tests passed!"
