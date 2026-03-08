/*
 * matiec_stubs.c — Provide runtime symbols expected by MATIEC-generated code.
 *
 * MATIEC's generated code references these extern globals which are normally
 * provided by the OpenPLC runtime. For standalone benchmarking we define them
 * here with zero-initialized values.
 */

#include "iec_types_all.h"

TIME __CURRENT_TIME;
