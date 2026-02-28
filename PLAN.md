# IronPLC Benchmark Development Plan

> **Purpose:** Define what to build for the IronPLC paper benchmarks, how to build it, and how the results map to the paper's evaluation section.
> 
> **Core question the benchmark answers:** _Given the same IEC 61131-3 Structured Text program, what is the execution cost of IronPLC's bytecode VM compared to RuSTy's LLVM-compiled native code, and does IronPLC's cycle time remain within real-time PLC budgets?_

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Benchmark Programs](#2-benchmark-programs)
3. [Component 1 — `ironplcc bench` Subcommand](#3-component-1--ironplcc-bench-subcommand)
4. [Component 2 — RuSTy Execution Harness](#4-component-2--rusty-execution-harness)
5. [Component 3 — Automation Script](#5-component-3--automation-script)
6. [Component 4 — Output Capture and Comparison](#6-component-4--output-capture-and-comparison)
7. [Component 5 — Report Generator](#7-component-5--report-generator)
8. [Repository Layout](#8-repository-layout)
9. [Build and Run Instructions](#9-build-and-run-instructions)
10. [Paper Section Outline](#10-paper-section-outline)

---

## 1. Architecture Overview

The benchmark compares two execution paths for the **same ST source file**:

```
traffic_light.st
     │
     ├─── RuSTy (plc) ──────► native .so ──► harness binary ──► T_rusty_{O0,O2}.json
     │
     └─── IronPLC (ironplcc) ► .plc container ► ironplcc bench ► T_ironplc.json
                                                      │
                                                      └──────────► variables.json
                                                                       │
                                                      rusty_vars.json ─┘
                                                                       │
                                                               compare_outputs.py
                                                                       │
                                                              PASS / FAIL + diff
```

**Critical design constraint:** The VM must be completely unaware it is being benchmarked. All timing is caller-side, outside `run_round`. No instrumentation code touches the hot dispatch loop. Production performance is identical whether the `bench` subcommand is used or not.

---

## 2. Benchmark Programs

Each program must be verified: it must compile and run correctly on RuSTy before being used as an IronPLC benchmark. Programs are drawn from the RuSTy test suite and OpenPLC examples, vendored at pinned commits.

### 2.1 Suite

|#|Name|Source|Key Features Exercised|
|---|---|---|---|
|1|`blinky.st`|OpenPLC examples|Minimal coil/contact; baseline|
|2|`ton_oneshot.st`|RuSTy test suite|TON timer, stateful FB|
|3|`counter_up.st`|RuSTy test suite|CTU counter, reset semantics|
|4|`arithmetic.st`|Custom / OSCAT|ADD, SUB, MUL, DIV, MOD, LIMIT|
|5|`for_loop.st`|RuSTy test suite|FOR loop, accumulator|
|6|`case_state.st`|OpenPLC examples|CASE statement, state machine|
|7|`nested_fb.st`|RuSTy test suite|FB calling FB, multiple instances|
|8|`array_sort.st`|Custom|Array indexing, bubble sort|

### 2.2 Selection Rationale

- **Blinky** is the "hello world" — if this fails or is slow, everything else is irrelevant. It establishes the baseline VM overhead with near-zero program logic.
- **TON / CTU** exercise stateful function block instances, which are the dominant pattern in real PLC programs.
- **Arithmetic** produces analytically verifiable outputs, making correctness checking trivial and exact.
- **FOR loop and CASE** exercise control flow opcodes (JMP, JMP_IF, JMP_UNLESS) which are the next major opcodes to implement after arithmetic.
- **Nested FB** tests the call stack and variable scoping, which are architecturally significant for the VM.
- **Array sort** is memory-access-heavy and exercises the indexing opcodes.

### 2.3 Minimum Viable Benchmark Set

If the IronPLC compiler front-end is not yet complete enough to compile all programs, the paper can proceed with programs 1–5. Programs 6–8 are stretch goals that strengthen the evaluation but are not required for publication.

---

## 3. Component 1 — `ironplcc bench` Subcommand

### 3.1 What It Does

Loads a compiled IronPLC `.plc` container, runs it for a configurable number of scan cycles, measures per-cycle wall time, and emits a structured JSON report. Optionally captures the final variable state for correctness comparison.

### 3.2 Where It Lives

```
compiler/ironplcc/src/commands/bench.rs
compiler/ironplcc/src/commands/mod.rs   (add bench variant)
compiler/ironplcc/src/args.rs           (add BenchArgs struct)
```

### 3.3 CLI Interface

```
ironplcc bench [OPTIONS] <FILE.plc>

Arguments:
  <FILE.plc>              Compiled IronPLC container

Options:
  --cycles <N>            Number of measured scan cycles [default: 10000]
  --warmup <N>            Unmeasured warmup cycles [default: 1000]
  --tick-us <N>           Simulated clock tick per cycle in microseconds [default: 1000]
  --capture-output <PATH> Write final variable state as JSON to PATH
  --report-format <FMT>   Output format: text (default) | json
  --pin-cpu               Pin to CPU 0 using sched_setaffinity (Linux only)
```

### 3.4 Implementation

```rust
// compiler/ironplcc/src/commands/bench.rs

pub struct BenchArgs {
    pub file: PathBuf,
    pub cycles: usize,
    pub warmup: usize,
    pub tick_us: u64,
    pub capture_output: Option<PathBuf>,
    pub report_format: ReportFormat,
    pub pin_cpu: bool,
}

pub struct BenchReport {
    pub program: String,
    pub cycles: usize,
    pub warmup: usize,
    pub mean_us: f64,
    pub p50_us: f64,
    pub p99_us: f64,
    pub max_us: f64,
    pub min_us: f64,
}

pub fn run(args: &BenchArgs) -> anyhow::Result<()> {
    #[cfg(target_os = "linux")]
    if args.pin_cpu {
        pin_to_cpu(0)?;
    }

    let bytes = std::fs::read(&args.file)?;
    let container = Container::from_bytes(&bytes)?;
    let mut buffers = VmBuffers::from_container(&container);

    let mut vm = Vm::new()
        .load(&container, /* ...buffers... */)
        .start();

    // Warmup — not measured, allows caches to stabilise
    for i in 0..args.warmup {
        vm.run_round(i as u64 * args.tick_us)
          .map_err(|e| anyhow::anyhow!("Trap during warmup: {:?}", e))?;
    }

    // Pre-allocate to avoid heap allocation during measurement
    let mut durations_ns: Vec<u64> = Vec::with_capacity(args.cycles);

    for i in 0..args.cycles {
        let t = (args.warmup + i) as u64 * args.tick_us;
        let t0 = Instant::now();
        vm.run_round(t)
          .map_err(|e| anyhow::anyhow!("Trap at cycle {i}: {:?}", e))?;
        durations_ns.push(t0.elapsed().as_nanos() as u64);
    }

    // Variable capture — after measurement loop, no overhead impact
    if let Some(ref path) = args.capture_output {
        capture_variables(&vm, path)?;
    }

    let report = compute_report(args, &mut durations_ns);
    emit_report(&report, &args.report_format);
    Ok(())
}

fn compute_report(args: &BenchArgs, durations_ns: &mut Vec<u64>) -> BenchReport {
    durations_ns.sort_unstable();
    let n = durations_ns.len();
    let sum: u64 = durations_ns.iter().sum();
    BenchReport {
        program: args.file.display().to_string(),
        cycles: args.cycles,
        warmup: args.warmup,
        mean_us: (sum as f64 / n as f64) / 1_000.0,
        p50_us:  durations_ns[n * 50 / 100] as f64 / 1_000.0,
        p99_us:  durations_ns[n * 99 / 100] as f64 / 1_000.0,
        max_us:  durations_ns[n - 1] as f64 / 1_000.0,
        min_us:  durations_ns[0] as f64 / 1_000.0,
    }
}

fn capture_variables(vm: &VmRunning, path: &Path) -> anyhow::Result<()> {
    let mut map = serde_json::Map::new();
    for i in 0..vm.num_variables() {
        if let Ok(v) = vm.read_variable(i) {
            map.insert(format!("var_{i}"), serde_json::Value::Number(v.into()));
        }
    }
    std::fs::write(path, serde_json::to_string_pretty(&map)?)?;
    Ok(())
}
```

### 3.5 JSON Output Format

```json
{
  "program": "traffic_light.plc",
  "cycles": 10000,
  "warmup": 1000,
  "durations_us": {
    "mean": 4.2,
    "p50":  4.1,
    "p99":  6.8,
    "min":  3.9,
    "max": 12.3
  }
}
```

### 3.6 What This Does NOT Touch

- `Vm`, `VmRunning`, `VmReady`, `VmStopped`, `VmFaulted` — unchanged
- `execute()` free function — unchanged
- `run_round()` — unchanged
- No feature flags, no conditional compilation anywhere in the VM crate

---

## 4. Component 2 — RuSTy Execution Harness

### 4.1 What It Does

A small standalone Rust binary that dynamically loads a RuSTy-compiled shared library, calls the program entry point N times, and emits the same JSON report format as `ironplcc bench`. Using the same format means a single `report.py` can consume both without special-casing.

### 4.2 Where It Lives

```
benchmarks/rusty_harness/
  Cargo.toml
  src/main.rs
```

### 4.3 How RuSTy Exposes the Program

RuSTy compiles ST to a shared object with a predictable symbol naming scheme. The entry point and initializer symbols can be discovered with:

```bash
plc traffic_light.st --shared -o traffic_light.so
nm -D traffic_light.so | grep ' T '
```

The harness takes `--entry` and `--init` as CLI arguments so it works with any symbol name without recompilation.

### 4.4 Implementation

```rust
// benchmarks/rusty_harness/src/main.rs

use libloading::{Library, Symbol};
use std::time::Instant;

#[derive(clap::Parser)]
struct Args {
    #[arg(long)] lib: PathBuf,
    #[arg(long)] entry: String,
    #[arg(long)] init: Option<String>,
    #[arg(long, default_value = "10000")] cycles: usize,
    #[arg(long, default_value = "1000")]  warmup: usize,
    #[arg(long)] capture_output: Option<PathBuf>,
    #[arg(long)] opt_level: String,   // "O0" or "O2" — metadata only
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let lib = unsafe { Library::new(&args.lib)? };

    if let Some(ref sym) = args.init {
        let init: Symbol<unsafe extern "C" fn()> = unsafe { lib.get(sym.as_bytes())? };
        unsafe { init() };
    }

    let entry: Symbol<unsafe extern "C" fn()> = unsafe {
        lib.get(args.entry.as_bytes())?
    };

    // Warmup
    for _ in 0..args.warmup {
        unsafe { entry() };
    }

    // Measured
    let mut durations_ns: Vec<u64> = Vec::with_capacity(args.cycles);
    for _ in 0..args.cycles {
        let t0 = Instant::now();
        unsafe { entry() };
        durations_ns.push(t0.elapsed().as_nanos() as u64);
    }

    emit_report(&args, &mut durations_ns);
    Ok(())
}
```

### 4.5 Dependencies

```toml
# benchmarks/rusty_harness/Cargo.toml
[dependencies]
libloading = "0.8"
clap       = { version = "4", features = ["derive"] }
serde_json = "1"
anyhow     = "1"
```

### 4.6 Compiling RuSTy Shared Libraries

```bash
# Unoptimized baseline — isolates interpreter vs. dispatch overhead
plc traffic_light.st --shared -o out/traffic_light_O0.so

# Production-optimized — realistic ceiling for native code
plc traffic_light.st --shared -O2 -o out/traffic_light_O2.so
```

> **Note on `__init__`:** RuSTy's documentation states the initializer is not called automatically on non-x86 architectures. The harness always calls it explicitly before the measurement loop for consistent cross-platform behavior.

---

## 5. Component 3 — Automation Script

### 5.1 What It Does

Orchestrates the full pipeline for a single ST source file: compile with both toolchains, run both harnesses, compare outputs, emit a combined report. Designed to be called from CI or manually during paper preparation.

### 5.2 Where It Lives

```
benchmarks/run_benchmark.sh
benchmarks/run_all.sh
```

### 5.3 `run_benchmark.sh`

```bash
#!/usr/bin/env bash
# Usage: ./benchmarks/run_benchmark.sh benchmarks/programs/blinky.st
set -euo pipefail

ST_FILE="$1"
NAME="$(basename "$ST_FILE" .st)"
CYCLES="${CYCLES:-10000}"
WARMUP="${WARMUP:-1000}"
TICK_US="${TICK_US:-1000}"
OUT="results/$NAME"
mkdir -p "$OUT" out/

echo "── $NAME ──────────────────────────────────────────"

# 1. Compile with RuSTy at both optimization levels
echo "[1/6] RuSTy O0..."
plc "$ST_FILE" --shared -o "out/${NAME}_O0.so"

echo "[2/6] RuSTy O2..."
plc "$ST_FILE" --shared -O2 -o "out/${NAME}_O2.so"

# 2. Compile with IronPLC
echo "[3/6] IronPLC compile..."
ironplcc compile "$ST_FILE" -o "out/${NAME}.plc"

# 3. Discover RuSTy symbols
ENTRY="$(nm -D "out/${NAME}_O0.so" | awk '/T [^_]/ {print $3}' | head -1)"
INIT="$(nm -D  "out/${NAME}_O0.so" | awk '/T __init__/ {print $3}' | head -1)"

# 4. Run harnesses
echo "[4/6] RuSTy O0 run..."
./benchmarks/rusty_harness/target/release/rusty_harness \
  --lib "out/${NAME}_O0.so" --entry "$ENTRY" --init "$INIT" \
  --cycles "$CYCLES" --warmup "$WARMUP" --opt-level O0 \
  > "$OUT/rusty_O0.json"

echo "[5/6] RuSTy O2 run..."
./benchmarks/rusty_harness/target/release/rusty_harness \
  --lib "out/${NAME}_O2.so" --entry "$ENTRY" --init "$INIT" \
  --cycles "$CYCLES" --warmup "$WARMUP" --opt-level O2 \
  > "$OUT/rusty_O2.json"

echo "[6/6] IronPLC run..."
ironplcc bench "out/${NAME}.plc" \
  --cycles "$CYCLES" --warmup "$WARMUP" --tick-us "$TICK_US" \
  --capture-output "$OUT/ironplc_vars.json" \
  --report-format json \
  > "$OUT/ironplc.json"

# 5. Correctness check
python3 benchmarks/tools/compare_outputs.py \
  "$OUT/rusty_vars.json" \
  "$OUT/ironplc_vars.json"

# 6. Combined report
python3 benchmarks/tools/report.py \
  --name "$NAME" \
  --rusty-O0 "$OUT/rusty_O0.json" \
  --rusty-O2 "$OUT/rusty_O2.json" \
  --ironplc  "$OUT/ironplc.json"

echo "Done. Results in $OUT/"
```

### 5.4 `run_all.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

PROGRAMS=(
  benchmarks/programs/blinky.st
  benchmarks/programs/ton_oneshot.st
  benchmarks/programs/counter_up.st
  benchmarks/programs/arithmetic.st
  benchmarks/programs/for_loop.st
  benchmarks/programs/case_state.st
)

for prog in "${PROGRAMS[@]}"; do
  ./benchmarks/run_benchmark.sh "$prog"
done

python3 benchmarks/tools/summary_table.py results/
```

---

## 6. Component 4 — Output Capture and Comparison

### 6.1 IronPLC Side

Implemented via `--capture-output` in `ironplcc bench` (see Component 1). Serializes the final variable store to JSON after all measured cycles complete. This adds no overhead to the measurement loop — the write happens after the timing window closes.

### 6.2 RuSTy Side

RuSTy-compiled programs hold state in memory accessible via the shared library's symbol table. The cleanest approach is to add a thin companion inspection function to each benchmark ST file that the harness calls after the measurement loop:

```iecst
(* Appended to blinky.st — compiled into the same .so *)
(* Harness calls blinky_get_outputs() after measurement *)
FUNCTION blinky_get_outputs : BOOL
VAR_EXTERNAL
    output_coil : BOOL;
    cycle_count : DINT;
END_VAR
    (* Variables are accessible via nm / dlsym in the harness *)
END_FUNCTION
```

The harness discovers output variable addresses via `dlsym` and writes them to JSON. Alternatively, for the paper, correctness can be verified by checking only a representative subset of variables (the semantically meaningful outputs) rather than the full variable store.

### 6.3 `compare_outputs.py`

```python
#!/usr/bin/env python3
"""
Compare variable output JSON from RuSTy and IronPLC.
Exit 0 on match, 1 on mismatch.
Usage: compare_outputs.py rusty_vars.json ironplc_vars.json
"""
import json, sys

def load(path):
    with open(path) as f:
        return json.load(f)

rusty   = load(sys.argv[1])
ironplc = load(sys.argv[2])

mismatches = []
for var, expected in rusty.items():
    actual = ironplc.get(var)
    if actual != expected:
        mismatches.append((var, expected, actual))

if mismatches:
    print("FAIL")
    for var, exp, act in mismatches:
        print(f"  {var}: expected={exp} actual={act}")
    sys.exit(1)

print(f"PASS  ({len(rusty)} variables verified)")
```

---

## 7. Component 5 — Report Generator

### 7.1 `report.py` — Per-Program Report

Reads three JSON result files and emits a formatted comparison table to stdout.

```
Program: blinky
Cycles:  10,000  (warmup: 1,000)

                  mean µs    p50 µs    p99 µs    max µs
RuSTy  -O0           0.3       0.3       0.5       1.2
RuSTy  -O2           0.1       0.1       0.2       0.4
IronPLC              2.1       2.0       3.1       6.8

Overhead vs -O0:   7.0x  (mean)
Overhead vs -O2:  21.0x  (mean)
```

### 7.2 `summary_table.py` — Cross-Program Table for Paper

Aggregates all per-program results into the table that goes directly into the paper, with a 1 ms real-time budget check column.

```
Program          IronPLC p99    RuSTy -O2 p99    Overhead    1 ms budget
blinky                2.1 µs          0.2 µs       10.5x         ✓
ton_oneshot           6.8 µs          0.4 µs       17.0x         ✓
counter_up            5.1 µs          0.3 µs       17.0x         ✓
arithmetic            4.3 µs          0.3 µs       14.3x         ✓
for_loop             12.4 µs          0.7 µs       17.7x         ✓
case_state            8.9 µs          0.5 µs       17.8x         ✓
```

---

## 8. Repository Layout

```
benchmarks/
  programs/                    # ST source files (vendored at pinned commits)
    blinky.st
    ton_oneshot.st
    counter_up.st
    arithmetic.st
    for_loop.st
    case_state.st
    nested_fb.st
    array_sort.st
    SOURCES.md                 # Provenance, license, upstream commit hash per file
  rusty_harness/               # Component 2
    Cargo.toml
    src/main.rs
  tools/                       # Components 4 & 5
    compare_outputs.py
    report.py
    summary_table.py
  run_benchmark.sh             # Component 3
  run_all.sh
  README.md                    # Reproduction instructions for paper reviewers
  results/                     # Generated at runtime — in .gitignore
    .gitkeep
  reference_results/           # Checked in — the paper's actual numbers
    blinky/
      rusty_O0.json
      rusty_O2.json
      ironplc.json
    ...                        # One directory per benchmark program

compiler/
  ironplcc/
    src/
      commands/
        bench.rs               # Component 1
        mod.rs                 # Add Bench variant
      args.rs                  # Add BenchArgs
```

---

## 9. Build and Run Instructions

These go into `benchmarks/README.md` for paper reviewers.

### Prerequisites

```bash
# RuSTy (pinned to commit used for paper)
cargo install --git https://github.com/PLC-lang/rusty --rev <COMMIT_HASH> plc

# IronPLC (from this repository)
cargo install --path compiler/ironplcc

# Build the RuSTy harness
cargo build --release --manifest-path benchmarks/rusty_harness/Cargo.toml

# Python dependencies
pip install tabulate
```

### Run Full Suite

```bash
./benchmarks/run_all.sh
```

### Run Single Program

```bash
./benchmarks/run_benchmark.sh benchmarks/programs/blinky.st
```

### Reproducibility Notes

- Results in `benchmarks/reference_results/` were collected on `<CPU>`, `<OS>`, kernel `<version>`.
- Absolute timings vary by hardware. The overhead ratio (IronPLC p99 / RuSTy O2 p99) is expected to be stable across x86-64 platforms.
- RuSTy was pinned to commit `<hash>`. IronPLC was built from commit `<hash>`.
- For lower variance, increase cycles: `CYCLES=100000 ./benchmarks/run_all.sh`

---

## 10. Paper Section Outline

---

### 5 Evaluation

#### 5.1 Goals

We evaluate IronPLC along two axes. The first is **correctness**: given a program that executes correctly on an established IEC 61131-3 runtime, does IronPLC produce identical output values? The second is **performance**: what is the cost of IronPLC's interpreted VM execution relative to RuSTy's LLVM-compiled native code, and does IronPLC's absolute cycle time remain within the real-time envelope required by target applications?

---

#### 5.2 Benchmark Programs

Programs were drawn from the RuSTy test suite and OpenPLC example library, vendored at pinned commits and listed with provenance in Table 1. All programs compile and execute correctly on RuSTy prior to use as IronPLC benchmarks.

_Table 1: Benchmark suite._

|Program|Source|Key Features|
|---|---|---|
|Blinky|OpenPLC|Minimal coil; baseline VM overhead|
|TON one-shot|RuSTy tests|Stateful function block, timer semantics|
|Counter (CTU)|RuSTy tests|Stateful function block, reset|
|Arithmetic|OSCAT / custom|ADD, SUB, MUL, LIMIT; verifiable outputs|
|FOR accumulator|RuSTy tests|Loop control flow|
|CASE state machine|OpenPLC|Branch-heavy control|

Programs 1–4 form the minimum set required to validate the VM's arithmetic and stateful FB execution. Programs 5–6 extend coverage to control flow opcodes.

---

#### 5.3 Experimental Setup

**Toolchains.** IronPLC compiles ST source to bytecode via `ironplcc compile` and executes via the `ironplcc bench` subcommand. RuSTy compiles the same ST source to a native shared library via `plc --shared`, which is then executed by a thin Rust harness that calls the program entry point in a loop. RuSTy is evaluated at two optimization levels: `-O0` (unoptimized, a fairer baseline that isolates the interpreter-vs-dispatch distinction from LLVM's optimizer) and `-O2` (production-grade, the realistic ceiling for native execution).

**Measurement protocol.** Each program runs for 1,000 warmup cycles (unmeasured) followed by 10,000 measured cycles. Warmup stabilises instruction and data caches. All processes are pinned to a single CPU core via `sched_setaffinity`. Timing uses `CLOCK_MONOTONIC_RAW` on Linux, which is unaffected by NTP adjustments. We report mean, p50, p99, and max cycle time. **p99 is the primary metric** because it governs worst-case latency, which determines real-time deployability.

**Equivalence of measurement.** The IronPLC `bench` subcommand places `Instant::now()` calls outside `run_round`, so the VM executes identically to production. The RuSTy harness places equivalent timing calls outside the entry point call. Both harnesses use the same JSON report format; the summary table is generated by a single Python script consuming both.

**Correctness verification.** After each run, IronPLC's final variable state is compared element-wise against RuSTy's final variable state using `compare_outputs.py`. A program passes only if all output variables are identical.

**Hardware.** `<CPU model, core count, clock speed>`, `<RAM>`, `<OS and version>`, kernel `<version>`.

---

#### 5.4 Correctness Results

All N programs in the benchmark suite produce identical output values when executed by IronPLC and RuSTy for 10,000 scan cycles. This confirms that IronPLC's bytecode semantics match the IEC 61131-3 specification for the language features exercised by the suite. _(If any programs required debugging to reach this result, describe the defect and fix in one sentence each.)_

---

#### 5.5 Performance Results

_Table 2: Per-cycle execution time (µs), 10,000 cycles._

|Program|RuSTy -O0 p99|RuSTy -O2 p99|IronPLC p99|Overhead vs -O2|1 ms budget|
|---|---|---|---|---|---|
|Blinky|||||✓|
|TON one-shot|||||✓|
|Counter|||||✓|
|Arithmetic|||||✓|
|FOR loop|||||✓|
|CASE state|||||✓|

IronPLC's interpreted execution is Nx–Mx slower than RuSTy's LLVM-optimized native code (Table 2). This overhead is consistent with published comparisons between bytecode interpreters and native code in other domains. Despite this overhead, IronPLC's p99 cycle time remains below Y µs across all benchmark programs — well within the 1 ms cycle budget common in industrial PLC applications.

The overhead relative to unoptimized RuSTy (`-O0`) narrows to Px–Qx, establishing that a substantial portion of RuSTy's advantage at `-O2` derives from LLVM optimization rather than the compiled-vs-interpreted distinction alone.

---

#### 5.6 Discussion

**Interpreter overhead.** The Nx overhead ratio is expected for a pure interpreter with no JIT compilation. IronPLC's dispatch loop uses a Rust `match` on the opcode byte, which the compiler lowers to a jump table. There is no per-opcode overhead from dynamic dispatch or boxing; all values are stored as fixed-width `Slot` types in pre-allocated buffers. The dominant cost is the interpreter loop itself relative to native code where loop overhead is compiled away entirely.

**Real-time viability.** The 1 ms cycle budget is conservative; non-safety- critical PLC applications commonly use 10–100 ms cycle times. At these rates, IronPLC's absolute cycle time is negligible and the interpretation overhead is immaterial. For hard real-time applications requiring sub-millisecond cycles, compilation-based approaches such as RuSTy remain preferable. IronPLC targets the large class of applications where interpreted execution is acceptable in exchange for the safety guarantees of all-safe-Rust execution, cross-platform portability, and the open-source tooling ecosystem.

**Threats to validity.**

1. The benchmark programs are small; real PLC programs may be larger and exhibit different instruction cache behaviour.
2. Measurements were taken on a general-purpose OS without real-time scheduling. Production deployments on PREEMPT_RT or dedicated hardware would see different absolute timings and lower variance.
3. RuSTy and IronPLC do not share a compiler front-end; the same ST source was compiled independently by each toolchain. Programs were manually verified to be semantically equivalent by comparing output traces.

---

#### Related Work (excerpt)

> The performance tradeoff between interpreted and compiled execution of domain-specific languages has been studied extensively in the context of JVM bytecode, CPython, and embedded scripting languages. In the IEC 61131-3 domain, no prior open-source work provides a systematic runtime benchmark comparing interpreted and compiled execution of Structured Text programs. RuSTy provides a compiler correctness test suite verified against LLVM IR output, but does not include a runtime execution harness. OpenPLC provides example programs but no formal benchmark suite. This work contributes the first open-source benchmark harness for IEC 61131-3 runtime execution, published alongside IronPLC as a reusable tool for the IEC 61131-3 implementation community.

---

## Implementation Order

Build in this sequence. Each step produces something independently useful and unblocks the next.

|Step|Component|Deliverable|Unblocks|
|---|---|---|---|
|1|`ironplcc bench` (timing only)|Can measure IronPLC cycle time|Everything else|
|2|RuSTy harness binary|Can measure RuSTy cycle time|Steps 3–7|
|3|`run_benchmark.sh`|Single command runs both|Paper workflow|
|4|`--capture-output` + `compare_outputs.py`|Correctness verification|Section 5.4|
|5|`report.py` + `summary_table.py`|Paper tables|Section 5.5|
|6|Benchmark programs 6–8|Broader evaluation|Stronger paper|
|7|`README.md` + `SOURCES.md` + pinned commits|Reproducibility|Submission|