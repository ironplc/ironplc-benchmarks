#!/usr/bin/env bash
# matiec_compile.sh — Compile an IEC 61131-3 ST file to a shared library
# via MATIEC (iec2c) and GCC.
#
# Usage:
#   ./benchmarks/matiec_compile.sh <ST_FILE> <OPT_LEVEL> <OUTPUT_SO>
#   ./benchmarks/matiec_compile.sh benchmarks/programs/blinky.st O0 out/blinky_matiec_O0.so
#
# Requires:
#   - iec2c on PATH
#   - MATIEC_C_INCLUDE_PATH pointing to the MATIEC runtime C headers (lib/C/)
#   - MATIEC_IEC_INCLUDE_PATH pointing to the MATIEC IEC library defs (lib/)
#     (defaults to MATIEC_C_INCLUDE_PATH/../ if not set)
#   - gcc

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <ST_FILE> <OPT_LEVEL> <OUTPUT_SO>" >&2
    exit 1
fi

ST_FILE="$1"
OPT="${2:-O2}"       # O0 or O2
OUTPUT="$3"
NAME="$(basename "$ST_FILE" .st)"
WORK="out/matiec_${NAME}_${OPT}"

if [[ -z "${MATIEC_C_INCLUDE_PATH:-}" ]]; then
    echo "ERROR: MATIEC_C_INCLUDE_PATH is not set" >&2
    echo "  Set it to the MATIEC lib/C directory (containing iec_types_all.h)" >&2
    exit 1
fi

# IEC library path (contains ieclib.txt etc.) — parent of the C headers dir
MATIEC_IEC_INCLUDE_PATH="${MATIEC_IEC_INCLUDE_PATH:-$(dirname "${MATIEC_C_INCLUDE_PATH}")}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUBS="${SCRIPT_DIR}/matiec_stubs.c"

mkdir -p "$WORK"

# Stage 1: ST → C via iec2c
# -I points to the IEC library definitions (ieclib.txt), not the C headers
echo "[matiec] ${NAME}: iec2c → ${WORK}/"
iec2c -I "${MATIEC_IEC_INCLUDE_PATH}" -T "$WORK" "$ST_FILE"

# Stage 2: C → shared library via GCC
# MATIEC generates config0.c, res0.c, and POUS.c. However res0.c does
# #include "POUS.c" directly, so we must NOT compile POUS.c separately.
echo "[matiec] ${NAME}: gcc -${OPT} → ${OUTPUT}"
gcc -shared -fPIC "-${OPT}" \
    -I "$WORK" \
    -I "${MATIEC_C_INCLUDE_PATH}" \
    "$WORK"/config0.c \
    "$WORK"/res0.c \
    "$STUBS" \
    -o "$OUTPUT" \
    -lm

echo "[matiec] ${NAME}: done → ${OUTPUT}"
