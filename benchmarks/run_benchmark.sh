#!/usr/bin/env bash
# run_benchmark.sh — Run a single ST program through both IronPLC and RuSTy,
# collecting JSON benchmark results.
#
# Usage:
#   ./benchmarks/run_benchmark.sh benchmarks/programs/blinky.st
#
# Environment variables:
#   CYCLES   Number of measured scan cycles  (default: 10000)
#   WARMUP   Number of warmup cycles         (default: 1000)
#
# Requires: ironplcc, ironplcvm, plc (RuSTy), rusty-harness on PATH or built.
# Output:   results/<name>/ironplc.json, rusty_0.json, rusty_2.json

set -euo pipefail

ST_FILE="$1"
NAME="$(basename "$ST_FILE" .st)"
CYCLES="${CYCLES:-10000}"
WARMUP="${WARMUP:-1000}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
OUT="${ROOT_DIR}/out"
RESULTS="${ROOT_DIR}/results/${NAME}"
HARNESS="${ROOT_DIR}/benchmarks/rusty_harness/target/release/rusty-harness"

mkdir -p "${OUT}" "${RESULTS}"

echo "── ${NAME} ──────────────────────────────────────────"

# ------------------------------------------------------------------
# 1. Compile with IronPLC
# ------------------------------------------------------------------
echo "[1/6] IronPLC compile..."
ironplcc compile "${ST_FILE}" -o "${OUT}/${NAME}.iplc"

# ------------------------------------------------------------------
# 2. Compile with RuSTy at two optimization levels
# ------------------------------------------------------------------
echo "[2/6] RuSTy O0..."
plc "${ST_FILE}" --shared -Onone -o "${OUT}/${NAME}_0.so"

echo "[3/6] RuSTy O2..."
plc "${ST_FILE}" --shared -Odefault -o "${OUT}/${NAME}_2.so"

# ------------------------------------------------------------------
# 3. Discover RuSTy symbols for the harness
# ------------------------------------------------------------------
ENTRY="$(nm -D "${OUT}/${NAME}_0.so" | awk '/T '"${NAME}"'$/ {print $3}')"
if [[ -z "${ENTRY}" ]]; then
    # Fallback: first non-underscore text symbol
    ENTRY="$(nm -D "${OUT}/${NAME}_0.so" | awk '/T [^_]/ {print $3; exit}')"
fi
INIT="$(nm -D "${OUT}/${NAME}_0.so" | awk '/T __init__/ {print $3; exit}')"

echo "     entry=${ENTRY} init=${INIT:-<none>}"

INIT_FLAG=()
if [[ -n "${INIT}" ]]; then
    INIT_FLAG=(--init "${INIT}")
fi

# ------------------------------------------------------------------
# 4. Run IronPLC benchmark
# ------------------------------------------------------------------
echo "[4/6] IronPLC benchmark..."
ironplcvm benchmark "${OUT}/${NAME}.iplc" \
    --cycles "${CYCLES}" --warmup "${WARMUP}" \
    > "${RESULTS}/ironplc.json"

# ------------------------------------------------------------------
# 5. Run RuSTy O0 benchmark
# ------------------------------------------------------------------
echo "[5/6] RuSTy O0 benchmark..."
"${HARNESS}" \
    --lib "${OUT}/${NAME}_0.so" \
    --entry "${ENTRY}" "${INIT_FLAG[@]}" \
    --cycles "${CYCLES}" --warmup "${WARMUP}" \
    --opt-level 0 \
    > "${RESULTS}/rusty_0.json"

# ------------------------------------------------------------------
# 6. Run RuSTy O2 benchmark
# ------------------------------------------------------------------
echo "[6/6] RuSTy O2 benchmark..."
"${HARNESS}" \
    --lib "${OUT}/${NAME}_2.so" \
    --entry "${ENTRY}" "${INIT_FLAG[@]}" \
    --cycles "${CYCLES}" --warmup "${WARMUP}" \
    --opt-level 2 \
    > "${RESULTS}/rusty_2.json"

echo ""
echo "Done. Results in ${RESULTS}/"
ls -lh "${RESULTS}"/*.json
