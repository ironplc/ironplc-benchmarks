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
#   - MATIEC_C_INCLUDE_PATH pointing to the MATIEC runtime headers
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

mkdir -p "$WORK"

# Stage 1: ST → C via iec2c
echo "[matiec] ${NAME}: iec2c → ${WORK}/"
iec2c -I "${MATIEC_C_INCLUDE_PATH}" -T "$WORK" "$ST_FILE"

# Stage 2: C → shared library via GCC
# MATIEC generates: POUS.c, Res0.c, Config0.c (plus headers)
echo "[matiec] ${NAME}: gcc -${OPT} → ${OUTPUT}"
gcc -shared -fPIC "-${OPT}" \
    -I "$WORK" \
    -I "${MATIEC_C_INCLUDE_PATH}" \
    "$WORK"/POUS.c \
    "$WORK"/Res0.c \
    "$WORK"/Config0.c \
    -o "$OUTPUT" \
    -lm

echo "[matiec] ${NAME}: done → ${OUTPUT}"
