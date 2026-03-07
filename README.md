# IronPLC Benchmarks

Runtime benchmarks comparing [IronPLC](https://github.com/ironplc/ironplc)'s bytecode VM against [RuSTy](https://github.com/PLC-lang/rusty)'s LLVM-compiled native code for IEC 61131-3 Structured Text programs.

## Repository structure

```
benchmarks/
  programs/          # IEC 61131-3 Structured Text source files
    blinky.st        # Minimal coil toggle — baseline VM overhead
    arithmetic.st    # Integer arithmetic operations (verifiable outputs)
    counter_up.st    # Counter with reset — conditional logic
    for_loop.st      # FOR loop with accumulator — loop control flow
    case_state.st    # CASE-based state machine — branch opcodes
  rusty_harness/     # Rust binary that loads RuSTy-compiled .so files
    Cargo.toml
    src/main.rs
  build_libs.sh      # Compiles all ST programs to .so at O0 and O2
  results/           # Generated at runtime (git-ignored)
out/                 # Compiled .so files (git-ignored)
Dockerfile           # Dev container with Python 3, Rust, LLVM 21, and RuSTy
PLAN.md              # Detailed benchmarking plan and paper outline
```

## Prerequisites

**Option A — Dev Container (recommended)**

Open this repository in VS Code with the Dev Containers extension. The container provides Python 3.12, Rust, and LLVM 21. Then install the compilers:

```bash
python setup.py
```

**Option B — Docker**

```bash
docker build -t ironplc-bench .
docker run --rm -it -v "$PWD":/workspace ironplc-bench
python setup.py
```

**Option C — Local setup**

Install the following manually, then run `python setup.py`:

- Python 3.12+
- Rust 1.90+ (via [rustup](https://rustup.rs))
- LLVM 21 (required to compile RuSTy)
- flex, bison, autoconf, automake, libtool (required to build MATIEC)

## Compiling ST programs to shared libraries

The `build_libs.sh` script compiles all ST benchmark programs into shared libraries using the RuSTy compiler at two optimization levels (O0 and O2):

```bash
# Inside the Docker container (plc is pre-installed):
./benchmarks/build_libs.sh

# Or compile a single program:
./benchmarks/build_libs.sh blinky.st
```

This produces files in `out/`:
```
out/blinky_O0.so       # Unoptimized (LLVM O0)
out/blinky_O2.so       # Production-optimized (LLVM O2)
out/arithmetic_O0.so
out/arithmetic_O2.so
...
```

The Docker image includes the RuSTy compiler pinned to a specific commit for reproducibility. To change the pinned version, update the `RUSTY_REV` build argument in the Dockerfile.

## Building the benchmark harness

The RuSTy execution harness is a standalone Rust binary that dynamically loads a RuSTy-compiled shared library, calls the program entry point for a configurable number of scan cycles, and emits a JSON timing report.

```bash
cd benchmarks/rusty_harness
cargo build --release
```

The binary is produced at `benchmarks/rusty_harness/target/release/rusty-harness`.

### Harness usage

```
rusty-harness [OPTIONS] --lib <PATH> --entry <SYMBOL>

Options:
  --lib <PATH>         Path to the RuSTy-compiled shared library (.so)
  --entry <SYMBOL>     Symbol name of the program entry point (e.g. "blinky")
  --init <SYMBOL>      Symbol name of the initializer function (optional)
  --cycles <N>         Number of measured scan cycles [default: 10000]
  --warmup <N>         Number of unmeasured warmup cycles [default: 1000]
  --opt-level <LEVEL>  Optimization level metadata (e.g. "O0", "O2") [default: O0]
  --pin-cpu            Pin process to CPU 0 for lower variance (Linux only)
```

### Example: compiling and benchmarking a program with RuSTy

```bash
# Compile all programs to shared libraries
./benchmarks/build_libs.sh

# Discover exported symbols
nm -D out/blinky_O0.so | grep ' T '

# Run the benchmark
./benchmarks/rusty_harness/target/release/rusty-harness \
  --lib out/blinky_O0.so \
  --entry blinky \
  --init __init___blinky_st \
  --cycles 10000 \
  --warmup 1000 \
  --opt-level O0
```

### Output format

The harness emits a JSON report to stdout:

```json
{
  "program": "blinky.so",
  "opt_level": "O0",
  "cycles": 10000,
  "warmup": 1000,
  "durations_us": {
    "mean": 0.3,
    "p50": 0.3,
    "p99": 0.5,
    "min": 0.2,
    "max": 1.2
  }
}
```

## Benchmark programs

| Program | Description | Key features exercised |
|---|---|---|
| `blinky.st` | Toggles a boolean each cycle | Minimal baseline — variable read, NOT, write |
| `arithmetic.st` | Integer ADD, SUB, MUL, DIV, MOD | Analytically verifiable outputs |
| `counter_up.st` | Counter with reset at threshold | Comparison, conditional assignment (IF/ELSE) |
| `for_loop.st` | Sums integers 1..100 each cycle | Loop control flow (FOR/END_FOR) |
| `case_state.st` | 4-state machine cycling each scan | Branch opcodes (CASE/END_CASE) |

## CI

GitHub Actions runs on every push to `main` and `claude/**` branches, and on pull requests to `main`. The workflow includes three jobs:

- **Build Docker image** — builds the development container (including RuSTy) and compiles all ST programs to `.so` files
- **Build benchmark harness** — compiles `rusty-harness` in release mode and runs `cargo clippy`
- **Lint** — runs `ruff check`, `ruff format --check`, and `shellcheck`

## Linting

```bash
# Rust
cd benchmarks/rusty_harness
cargo clippy -- -D warnings

# Python
ruff check .
ruff format --check .
```

## License

See the [IronPLC repository](https://github.com/ironplc/ironplc) for license information.
