#!/bin/bash
# Run directed RTL unit test for BUG_006 (store queue wrap-around allocation).
# Default: Verilator (no Questa).
#
# Usage:
#   source SetEnv.sh   # optional: RSD_VERILATOR_BIN
#   ./bugs/run_bug006_unit_test.sh
#   ./bugs/run_bug006_unit_test.sh --with-bug   # inject BUG_006 first; test must fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNIT_DIR="$RSD_ROOT/Processor/Src/Verification/UnitTest/StoreQueueWrap"

WITH_BUG=0
for arg in "$@"; do
    case "$arg" in
        --with-bug) WITH_BUG=1 ;;
    esac
done

if [[ $WITH_BUG -eq 1 ]]; then
    echo "Injecting BUG_006..."
    python3 "$SCRIPT_DIR/inject.py" --bugs BUG_006 --rsd-root "$RSD_ROOT"
    trap 'python3 "'"$SCRIPT_DIR"'/inject.py" --restore --rsd-root "'"$RSD_ROOT"'"' EXIT
fi

cd "$UNIT_DIR"
echo "Building and running StoreQueueWrap unit test (Verilator)..."
export RSD_VERILATOR_BIN="${RSD_VERILATOR_BIN:-verilator}"
make -f Makefile.verilator.mk build run

if [[ $WITH_BUG -eq 1 ]]; then
    echo "Note: with BUG_006 injected, simulation should have failed above."
fi
