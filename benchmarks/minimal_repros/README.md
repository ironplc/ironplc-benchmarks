# IronPLC Minimal Failure Reproductions

Each `.st` file demonstrates a single IronPLC capability gap found via OSCAT
compatibility testing (`benchmarks/ironplc_compat.py`). Tested against v0.176.0.

## Summary

| # | File | Error | OSCAT Impact |
|---|------|-------|-------------|
| 1 | `01_cross_function_call.st` | compile.rs#L2116 — unresolved function call | ~49 functions |
| 1b | `01b_string_func_in_function.st` | compile.rs#L2513/L2537 — string stdlib in FUNCTION | ~10 functions |
| 1c | `01c_global_var_access.st` | compile.rs#L3307/L3302 — unresolved global variable | ~14 functions |
| 6 | `06_type_struct.st` | P0002 Syntax error on `END_TYPE` | part of ~38 |
| 7 | `07_array_indexing.st` | compile.rs#L3302 — array indexing | all array users |
| 9 | `09_ref_to.st` | P0003 Unmatched `^` | ~45 functions |

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

## Reproduce

```bash
ironplcc compile --output /tmp/test.iplc <file>.st
```
