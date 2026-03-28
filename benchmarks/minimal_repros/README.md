# IronPLC Minimal Failure Reproductions

Each `.st` file demonstrates a single IronPLC capability gap found via OSCAT
compatibility testing (`benchmarks/ironplc_compat.py`). Tested against v0.179.0.

## Summary

| # | File | Error | OSCAT Impact |
|---|------|-------|-------------|
| 1 | `01_cross_function_call.st` | compile.rs#L2116 — unresolved function call | ~49 functions |
| 1b | `01b_string_func_in_function.st` | compile.rs#L2513/L2537 — string stdlib in FUNCTION | ~10 functions |
| 1c | `01c_global_var_access.st` | compile.rs#L3307/L3302 — unresolved global variable | ~14 functions |
| 6 | `06_type_struct.st` | P0002 Syntax error on `END_TYPE` | part of ~38 |
| 7 | `07_array_indexing.st` | compile.rs#L3302 — array indexing | all array users |
| 9 | `09_ref_to.st` | P0003 Unmatched `^` | ~45 functions |
| 13 | `13_time_function_call.st` | P0002 — `TIME` keyword vs function call | 2 functions |
| 14 | `14_missing_semicolon_end_if.st` | P0002 — missing `;` after `END_IF` | 1 function |
| 15 | `15_end_struct_missing_semicolon.st` | P0002 — missing `;` after `END_STRUCT` | 7 functions |
| 16 | `16_var_temp.st` | P0002 — `VAR_TEMP` not recognized | 1 function + full-mode blocker |
| 17 | `17_c_style_comment.st` | P0003 — `/* */` C-style comments | 1 function |
| 18 | `18_undefined_function_error_message.st` | P9999 — misleading error for undefined function | ~40 functions |
| 19 | `19_implicit_int_conversion.st` | P4026 — DINT literal passed to INT parameter | 41 functions |
| 20 | `20_pointer_arithmetic.st` | P2033/P2035 — arithmetic/comparison on REF_TO | 29 functions |
| 21 | `21_ref_stack_variable.st` | P2029/P2032 — REF() of stack var + type punning | 9 functions |
| 22 | `22_undefined_global_variable.st` | P4007 — dotted globals (math.PI, phys.T0) | 32 functions |
| 23 | `23_undefined_constant_type_param.st` | P4030 — STRING[STRING_LENGTH] undefined | 9 functions |

### Root cause: unresolved externals (1, 1b, 1c)

All three `01*` repros share the same root cause: the codegen cannot resolve
references to functions/variables not defined in the current compilation unit.
This affects:
- User-defined functions calling other user-defined functions from different files
- String stdlib functions (LEN, FIND, REPLACE, etc.) called from FUNCTION context
- Global variable references (phys.T0, math.PI2, math.FACTS[X])

These all work when called from PROGRAM context or when the callee is defined
in the same file.

## Already fixed (no longer failing)

- **Cross-function calls (same file)** — fixed in v0.176.0
- **SHL/SHR with function call arg** — fixed in v0.176.0
- **Scientific notation (2E-3)** — fixed in v0.176.0
- **ABS() in user functions** — stdlib calls from user functions now work
- **VAR CONSTANT blocks** — parsed and compiled correctly
- **Bit access in functions** (`.0`, `.15`) — fixed
- **SHL/SHR with return variable** — fixed
- **Function locals reinitialization** — fixed in v0.175.0
- **LTIME as variable name** — renamed in OSCAT fork to LOCAL_TIME
- **REF_TO ARRAY declaration** — fixed in v0.179.0
- **REF_TO dereference+subscript (`PT^[i]`)** — fixed in v0.179.0
- **STRING[N] as function return type** — fixed in v0.179.0
- **STRING[N] in VAR, VAR CONSTANT, VAR_IN_OUT** — fixed in v0.179.0
- **STRING[N] in STRUCT members** — fixed in v0.179.0
- **Empty VAR blocks** — fixed in v0.179.0
- **VAR_TEMP** — fixed in v0.179.0
- **Missing `;` after END_IF/END_STRUCT** — fixed in v0.179.0
- **`TIME()` as function call** — fixed in v0.179.0
- **C-style comments `/* */`** — fixed in v0.179.0
- **Keyword as struct member (LDT)** — fixed in v0.179.0 via dialect system
- **ARRAY in local VAR** — fixed in v0.179.0

## Reproduce

```bash
ironplcc compile --dialect rusty --output /tmp/test.iplc <file>.st
```
