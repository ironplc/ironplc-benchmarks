#!/usr/bin/env bash
# build_libs.sh — Compile all ST benchmark programs into shared libraries
# using the RuSTy compiler at multiple optimization levels.
#
# Usage:
#   ./benchmarks/build_libs.sh                  # Compile all programs
#   ./benchmarks/build_libs.sh blinky.st        # Compile one program
#
# Requires: plc (RuSTy compiler) on PATH.
# Output:   out/<name>_O0.so, out/<name>_O2.so for each program.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="${SCRIPT_DIR}/programs"
OUT_DIR="${SCRIPT_DIR}/../out"

# RuSTy optimization levels:
#   -Onone       → LLVM O0 (unoptimized baseline)
#   -Odefault    → LLVM O2 (production-optimized)
declare -A OPT_LEVELS=(
    ["O0"]="-Onone"
    ["O2"]="-Odefault"
)

mkdir -p "${OUT_DIR}"

# Determine which programs to compile
if [[ $# -gt 0 ]]; then
    PROGRAMS=("$@")
else
    PROGRAMS=("${PROGRAMS_DIR}"/*.st)
fi

for st_file in "${PROGRAMS[@]}"; do
    # Resolve to full path if just a filename was given
    if [[ ! -f "${st_file}" ]]; then
        st_file="${PROGRAMS_DIR}/${st_file}"
    fi

    if [[ ! -f "${st_file}" ]]; then
        echo "ERROR: ${st_file} not found" >&2
        exit 1
    fi

    name="$(basename "${st_file}" .st)"

    for label in "${!OPT_LEVELS[@]}"; do
        opt_flag="${OPT_LEVELS[${label}]}"
        so_file="${OUT_DIR}/${name}_${label}.so"
        echo "[build] ${name} ${label} → ${so_file}"
        plc "${st_file}" --shared "${opt_flag}" -o "${so_file}"
    done
done

echo ""
echo "Done. Compiled libraries in ${OUT_DIR}:"
ls -lh "${OUT_DIR}"/*.so 2>/dev/null || echo "  (none)"
