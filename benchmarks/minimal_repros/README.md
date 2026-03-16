# IronPLC Minimal Failure Reproductions

Each `.st` file demonstrates a single IronPLC capability gap found via OSCAT
compatibility testing (`benchmarks/ironplc_compat.py`).

## Summary

| # | File | Error | OSCAT Impact | Edition |
|---|------|-------|-------------|---------|
| 1 | `01_cross_function_call.st` | codegen compile.rs#L2074 | ~49 functions | Ed.2 |
| 4 | `04_shl_with_function_arg.st` | codegen (hidden by terminal error) | ~15 functions | Ed.2 |
| 5 | `05_scientific_notation.st` | P0002 Syntax error on `2E-3` | part of ~38 | Ed.2 |
| 6 | `06_type_struct.st` | P0002 Syntax error on `END_TYPE` | part of ~38 | Ed.2 |
| 7 | `07_array_indexing.st` | codegen compile.rs#L3248 | all array users | Ed.2 |
| 9 | `09_ref_to.st` | P0003 Unmatched `^` | ~45 functions | Ed.3 |
| 10 | `10_ltime.st` | P0010 Requires Ed.3 flag | 1 function | Ed.3 |

## Already fixed (no longer failing)

- **ABS() in user functions** — stdlib calls from user functions now work
- **VAR CONSTANT blocks** — parsed and compiled correctly
- **Bit access in functions** (`.0`, `.15`) — fixed
- **SHL/SHR with return variable** — fixed
- **Function locals reinitialization** — fixed in v0.175.0

## Reproduce

```bash
ironplcc compile --output /tmp/test.iplc <file>.st
```
