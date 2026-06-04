#!/bin/bash
# Run directed RTL unit test for BUG_003 (store-to-load forwarding).
# Default: Verilator (no Questa). Use Questa only with --questa.
#
# Usage:
#   source SetEnv.sh   # optional: RSD_VERILATOR_BIN
#   ./bugs/run_bug003_unit_test.sh
#   ./bugs/run_bug003_unit_test.sh --with-bug   # inject BUG_003 first; test must fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNIT_DIR="$RSD_ROOT/Processor/Src/Verification/UnitTest/StoreForward"

WITH_BUG=0
USE_VERILATOR=1
for arg in "$@"; do
    case "$arg" in
        --with-bug) WITH_BUG=1 ;;
        --verilator) USE_VERILATOR=1 ;;
        --questa) USE_VERILATOR=0 ;;
    esac
done

if [[ $WITH_BUG -eq 1 ]]; then
    echo "Injecting BUG_003..."
    python3 "$SCRIPT_DIR/inject.py" --bugs BUG_003 --rsd-root "$RSD_ROOT"
    trap 'python3 "'"$SCRIPT_DIR"'/inject.py" --restore --rsd-root "'"$RSD_ROOT"'"' EXIT
fi

cd "$UNIT_DIR"
if [[ $USE_VERILATOR -eq 1 ]]; then
    echo "Building and running StoreForward unit test (Verilator)..."
    export RSD_VERILATOR_BIN="${RSD_VERILATOR_BIN:-verilator}"
    make -f Makefile.verilator.mk build run
else
    echo "Building and running StoreForward unit test (Questa)..."
    make run
fi

if [[ $WITH_BUG -eq 1 ]]; then
    echo "Note: with BUG_003 injected, simulation should have failed above."
fi
