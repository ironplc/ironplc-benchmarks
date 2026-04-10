# IronPLC Minimal Failure Reproductions

Each `.st` file demonstrates a single IronPLC capability gap found via OSCAT
compatibility testing (`benchmarks/ironplc_compat.py`). Tested against v0.184.0
(commit e4e65a3c).

## Summary

### Still failing

| # | File | Error | OSCAT Impact |
|---|------|-------|-------------|
| 1 | `01_cross_function_call.st` | P4017 - function not declared (cross-file) | ~49 functions |
| 1c | `01c_global_var_access.st` | P4007 - undefined global variable (cross-file) | ~14 functions |
| 10 | `10_ltime.st` | P0002 - LTIME# literal syntax not parsed | 1 function |
| 11 | `11_unused_functions.st` | P4017 - no tree-shaking of undefined function calls | test case |
| 12 | `12_terminal_error.st` | P4007 - undefined struct global variable | 8 functions |
| 13 | `13_time_function_call.st` | P4017 - TIME() function not declared | 2 functions |
| 18 | `18_undefined_function_error_message.st` | P4017 - misleading error for undefined function | ~40 functions |
| 22 | `22_undefined_global_variable.st` | P4007 - dotted globals (math.PI, phys.T0) | 32 functions |
| 23 | `23_undefined_constant_type_param.st` | P4030 - STRING[STRING_LENGTH] undefined constant | 9 functions |
| 31 | `31_time_date_conversions.st` | P4017 - TIME/DATE/TOD/DT conversion functions missing | date/time functions |
| 32 | `32_sizeof.st` | P4017 - SIZEOF not supported (CODESYS extension) | 8 functions |
| 33 | `33_implicit_integer_widening.st` | P4026 - INT to DINT, BYTE to INT widening rejected | **full-mode blocker** |

### Full-mode blocker (priority)

Issue 33: passing a narrower integer type (INT) to a wider parameter (DINT) fails
with P4026. In oscat.st, `EVEN(disc)` where `disc : INT` and `EVEN` takes `DINT`
triggers this, blocking all 294 testable functions. Same issue affects BYTE-to-INT
and INT-to-REAL widening.

### After #33 is fixed

The remaining errors in full oscat.st compilation are:
- **Missing functions** (P4017): time/date conversions (#31), string conversions,
  SIZEOF (#32), DAY_OF_WEEK, DT_TO_DATE, DT_TO_TOD
- **More implicit widening** (P4026/P4027): INT-to-REAL, BYTE-to-INT in various
  functions, BYTE return assigned to INT variable
- **ARRAY[0..n] with VAR_INPUT** (P4030): 4 instances in FUNCTION_BLOCKs

### Root cause: unresolved externals (1, 1c)

The `01*` repros share the same root cause: the compiler cannot resolve
references to functions/variables not defined in the current compilation unit.

## Already fixed (no longer failing)

- **Cross-function calls (same file)** - fixed in v0.176.0
- **SHL/SHR with function call arg** - fixed in v0.176.0
- **Scientific notation (2E-3)** - fixed in v0.176.0
- **ABS() in user functions** - stdlib calls from user functions now work
- **VAR CONSTANT blocks** - parsed and compiled correctly
- **Bit access in functions** (`.0`, `.15`) - fixed
- **SHL/SHR with return variable** - fixed
- **Function locals reinitialization** - fixed in v0.175.0
- **LTIME as variable name** - renamed in OSCAT fork to LOCAL_TIME
- **REF_TO ARRAY declaration** - fixed in v0.179.0
- **REF_TO dereference+subscript (`PT^[i]`)** - fixed in v0.179.0
- **STRING[N] as function return type** - fixed in v0.179.0
- **STRING[N] in VAR, VAR CONSTANT, VAR_IN_OUT** - fixed in v0.179.0
- **STRING[N] in STRUCT members** - fixed in v0.179.0
- **Empty VAR blocks** - fixed in v0.179.0
- **VAR_TEMP** - fixed in v0.179.0
- **Missing `;` after END_IF/END_STRUCT** - fixed in v0.179.0
- **`TIME()` as function call** - fixed in v0.179.0
- **C-style comments `/* */`** - fixed in v0.179.0
- **Keyword as struct member (LDT)** - fixed in v0.179.0 via dialect system
- **ARRAY in local VAR** - fixed in v0.179.0
- **String stdlib in FUNCTION** (01b) - fixed in v0.184.0
- **Array indexing** (07) - fixed in v0.184.0
- **REF_TO dereference** (09) - fixed in v0.184.0
- **Implicit INT conversion** (19) - fixed in v0.184.0
- **Pointer arithmetic** (20) - fixed in v0.184.0
- **REF() of stack variable** (21) - fixed in v0.184.0
- **BOOL integer initializer** (24) - fixed in v0.184.0
- **Forward ref global constant** (25) - fixed in v0.184.0
- **STRING field in TYPE STRUCT** (27) - fixed in v0.184.0
- **SEL/MUX return type when nested** (28) - fixed in v0.184.0
- **FB instantiation as duplicate POU** (29) - fixed in v0.184.0
- **Int literal to REAL param** (30) - fixed in v0.184.0 (e4e65a3c)
- **Struct field access in codegen** (06) - fixed in v0.184.0 (e4e65a3c)
- **ARRAY OF STRING[N]** (26) - fixed in v0.184.0 (e4e65a3c)

## Reproduce

```bash
ironplcc compile --dialect rusty -o /tmp/test.iplc <file>.st
```
