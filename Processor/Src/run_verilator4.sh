#!/usr/bin/env bash
set -euo pipefail

# Default Verilator binary from the conda environment we prepared.
DEFAULT_VERILATOR_BIN="/home/liaozhaopo/anaconda3/envs/rsd-verilator4/bin/verilator"

RSD_VERILATOR_BIN="${RSD_VERILATOR_BIN:-$DEFAULT_VERILATOR_BIN}"
MAKEFILE="${MAKEFILE:-Makefile.verilator.mk}"

usage() {
  cat <<'EOF'
Usage:
  ./run_verilator4.sh [build|run|clean|rebuild|kanata|dump]

Description:
  Wrapper for RSD Verilator 4.x flow with compatible tool overrides.

Examples:
  ./run_verilator4.sh build
  ./run_verilator4.sh run
  ./run_verilator4.sh rebuild

Environment overrides (optional):
  RSD_VERILATOR_BIN   Path to verilator binary
  MAKEFILE            Verilator makefile (default: Makefile.verilator.mk)
  EXTRA_MAKE_ARGS     Extra args passed to make
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ACTION="${1:-build}"
shift || true

if [[ ! -x "$RSD_VERILATOR_BIN" ]]; then
  echo "Error: verilator binary not found or not executable: $RSD_VERILATOR_BIN" >&2
  echo "Hint: export RSD_VERILATOR_BIN=/path/to/verilator" >&2
  exit 1
fi

COMMON_MAKE_ARGS=(
  -f "$MAKEFILE"
  CXX=g++
  LINK=g++
  PERL=perl
  PYTHON3=python3
  VM_PARALLEL_BUILDS=1
)

if [[ -n "${EXTRA_MAKE_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  COMMON_MAKE_ARGS+=(${EXTRA_MAKE_ARGS})
fi

case "$ACTION" in
  build)
    RSD_VERILATOR_BIN="$RSD_VERILATOR_BIN" make "${COMMON_MAKE_ARGS[@]}" "$@"
    ;;
  run|kanata|dump|clean)
    RSD_VERILATOR_BIN="$RSD_VERILATOR_BIN" make "${COMMON_MAKE_ARGS[@]}" "$ACTION" "$@"
    ;;
  rebuild)
    RSD_VERILATOR_BIN="$RSD_VERILATOR_BIN" make "${COMMON_MAKE_ARGS[@]}" clean "$@"
    RSD_VERILATOR_BIN="$RSD_VERILATOR_BIN" make "${COMMON_MAKE_ARGS[@]}" "$@"
    ;;
  *)
    echo "Error: unknown action '$ACTION'" >&2
    usage
    exit 1
    ;;
esac
