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
  run_benchmark.sh   # Run one program through both IronPLC and RuSTy
  run_all.sh         # Run all programs
  results/           # Generated at runtime (git-ignored)
Dockerfile           # Dev container with Python 3, Rust, LLVM 21, ironplcc, ironplcvm, plc
PLAN.md              # Detailed benchmarking plan and paper outline
```

## Prerequisites

**Option A — Docker (recommended)**

Build and run the development container, which includes Python 3.12, Rust, LLVM 21, `ironplcc`, `ironplcvm`, and `plc` (RuSTy):

```bash
docker build -t ironplc-bench .
docker run --rm -it -v "$PWD":/workspace ironplc-bench
```

**Option B — Dev Container**

Open this repository in VS Code with the Dev Containers extension. The `.devcontainer/devcontainer.json` configuration will build the same Docker image automatically.

**Option C — Local setup**

Install the following manually:

- Python 3.12+
- Rust 1.90+ (via [rustup](https://rustup.rs))
- LLVM 21 (required to compile RuSTy)

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
# Compile an ST program to a shared library with RuSTy
plc benchmarks/programs/blinky.st --shared -o blinky.so

# Discover exported symbols
nm -D blinky.so | grep ' T '

# Run the benchmark
./benchmarks/rusty_harness/target/release/rusty-harness \
  --lib blinky.so \
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

## Running benchmarks

The quickest way to run the full suite through both IronPLC and RuSTy is inside the Docker container:

```bash
# Build the RuSTy harness first
cd benchmarks/rusty_harness && cargo build --release && cd ../..

# Run all programs
./benchmarks/run_all.sh

# Or run a single program
./benchmarks/run_benchmark.sh benchmarks/programs/blinky.st
```

Results are written to `results/<name>/` with three JSON files per program:
- `ironplc.json` — IronPLC bytecode VM timing
- `rusty_0.json` — RuSTy with `-Onone` (LLVM O0)
- `rusty_2.json` — RuSTy with `-Odefault` (LLVM O2)

You can control the number of cycles via environment variables:

```bash
CYCLES=100000 WARMUP=5000 ./benchmarks/run_all.sh
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

GitHub Actions runs on every push to `main` and `claude/**` branches, and on pull requests to `main`. The workflow includes four jobs:

- **Build Docker image** — verifies the development container builds successfully (includes `ironplcc`, `ironplcvm`, and `plc`)
- **Build benchmark harness** — compiles `rusty-harness` in release mode and runs `cargo clippy`
- **Lint shell scripts** — runs ShellCheck on `benchmarks/*.sh`
- **Lint Python** — runs `ruff check` and `ruff format --check`

## Linting

```bash
# Rust
cd benchmarks/rusty_harness
cargo clippy -- -D warnings

# Shell
shellcheck benchmarks/*.sh

# Python
ruff check .
ruff format --check .
```

## License

See the [IronPLC repository](https://github.com/ironplc/ironplc) for license information.
