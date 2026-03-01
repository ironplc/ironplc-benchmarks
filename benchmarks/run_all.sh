#!/usr/bin/env bash
# run_all.sh — Run benchmarks for every ST program in benchmarks/programs/.
#
# Usage:
#   ./benchmarks/run_all.sh
#
# Environment variables (forwarded to run_benchmark.sh):
#   CYCLES   Number of measured scan cycles  (default: 10000)
#   WARMUP   Number of warmup cycles         (default: 1000)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="${SCRIPT_DIR}/programs"

FAILED=0

for st_file in "${PROGRAMS_DIR}"/*.st; do
    name="$(basename "${st_file}" .st)"
    echo ""
    echo "================================================================"
    echo "  ${name}"
    echo "================================================================"

    if "${SCRIPT_DIR}/run_benchmark.sh" "${st_file}"; then
        echo "[PASS] ${name}"
    else
        echo "[FAIL] ${name}" >&2
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "================================================================"
if [[ ${FAILED} -eq 0 ]]; then
    echo "All benchmarks completed successfully."
else
    echo "${FAILED} benchmark(s) failed." >&2
    exit 1
fi
