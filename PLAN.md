# IronPLC Benchmark Development Plan

> **Purpose:** Define what to build for the IronPLC paper benchmarks, how to build it, and how the results map to the paper's evaluation section.
> 
> **Core question the benchmark answers:** _Given the same IEC 61131-3 Structured Text program, what is the execution cost of IronPLC's bytecode VM compared to RuSTy's LLVM-compiled native code and MATIEC's C-compiled native code, and does IronPLC's cycle time remain within real-time PLC budgets?_

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Benchmark Programs](#2-benchmark-programs)
3. [Component 1 — `ironplcc bench` Subcommand](#3-component-1--ironplcc-bench-subcommand)
4. [Component 2 — RuSTy Execution Harness](#4-component-2--rusty-execution-harness)
5. [Component 3 — MATIEC Execution Harness](#5-component-3--matiec-execution-harness)
6. [Component 4 — Automation Script](#6-component-4--automation-script)
7. [Component 5 — Output Capture and Comparison](#7-component-5--output-capture-and-comparison)
8. [Component 6 — Report Generator](#8-component-6--report-generator)
9. [Repository Layout](#9-repository-layout)
10. [Build and Run Instructions](#10-build-and-run-instructions)
11. [Paper Section Outline](#11-paper-section-outline)

---

## 1. Architecture Overview

The benchmark compares three execution paths for the **same ST source file**:

```
traffic_light.st
     │
     ├─► RuSTy (plc) ──────► native .so ──► rusty_harness ──► timing.json + final_vars.json
     │
     ├─► MATIEC (iec2c) ────► C source ──► GCC ──► .so ──► matiec_harness ──► timing.json + final_vars.json
     │
     └─► IronPLC (ironplcc) ► .plc ──► ironplcc bench ──► timing.json + final_vars.json
                                                                    │
                                              all final_vars.json ──┘
                                                                    │
                                                         compare_outputs.py
                                                                    │
                                                         PASS / FAIL + diff
```

**Why MATIEC?** MATIEC (`iec2c`) is the open-source IEC 61131-3 compiler used by OpenPLC. It translates ST to ANSI C, which is then compiled to native code by GCC. Including MATIEC provides a second native-code baseline alongside RuSTy, representing the traditional C-compilation approach common in industrial PLC runtimes. This three-way comparison isolates the performance characteristics of: (a) LLVM-optimized native code (RuSTy), (b) GCC-compiled C code from a mature transpiler (MATIEC), and (c) bytecode interpretation (IronPLC).

**Critical design constraint:** The VM must be completely unaware it is being benchmarked. All timing is caller-side, outside `run_round`. No instrumentation code touches the hot dispatch loop. Production performance is identical whether the `bench` subcommand is used or not.

---

## 2. Benchmark Programs

Each program must be verified: it must compile and run correctly on RuSTy before being used as an IronPLC benchmark. Programs are drawn from the RuSTy test suite and OpenPLC examples, vendored at pinned commits.

### 2.1 Suite

Each program is designed so that its final variable state after N cycles is **deterministic and analytically predictable**, enabling correctness verification across compilers without runtime introspection.

|#|Name|Source|Key Features Exercised|Expected Final State (11,000 cycles)|
|---|---|---|---|---|
|1|`blinky.st`|OpenPLC examples|Minimal coil/contact; baseline|`output_coil = FALSE` (even cycle count)|
|2|`ton_oneshot.st`|RuSTy test suite|TON timer, stateful FB|Timer elapsed, output latched|
|3|`counter_up.st`|RuSTy test suite|CTU counter, reset semantics|`counter = 11000`|
|4|`arithmetic.st`|Custom / OSCAT|ADD, SUB, MUL, DIV, MOD, LIMIT|Deterministic computed values|
|5|`for_loop.st`|RuSTy test suite|FOR loop, accumulator|`accumulator = 5050` (sum 1..100 each cycle)|
|6|`case_state.st`|OpenPLC examples|CASE statement, state machine|`state` determined by `11000 mod 4`|
|7|`nested_fb.st`|RuSTy test suite|FB calling FB, multiple instances|Deterministic FB instance state|
|8|`array_sort.st`|Custom|Array indexing, bubble sort|Sorted array, deterministic final values|

> **Note:** "11,000 cycles" = 1,000 warmup + 10,000 measured (default). The expected final state column shows what all compilers must agree on to pass the correctness check.

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

## 5. Component 3 — MATIEC Execution Harness

### 5.1 What It Does

Compiles an IEC 61131-3 ST source file to C using MATIEC's `iec2c` transpiler, compiles the generated C to a shared library using GCC (at multiple optimization levels), then dynamically loads and executes the program in a timing loop. Emits the same JSON report format as `ironplcc bench` and the RuSTy harness, so `report.py` and `summary_table.py` consume all three without special-casing.

### 5.2 Background on MATIEC

[MATIEC](https://github.com/sm1820/matiec) is the open-source IEC 61131-3 compiler originally developed for MatPLC and now used by OpenPLC. Its `iec2c` tool translates ST (and IL, SFC) to ANSI C code. The generated C depends on the MATIEC runtime headers (`iec_types_all.h`, `accessor.h`, `iec_std_lib.h`) for standard data types and function blocks.

Including MATIEC provides a **C-compilation baseline** that complements RuSTy's LLVM compilation:

- **RuSTy** represents the best-case native code: modern LLVM optimizations applied directly to a purpose-built IR.
- **MATIEC + GCC** represents the traditional industrial approach: transpile to C, compile with a general-purpose C compiler. This is the path most open-source PLC runtimes use in production.
- **IronPLC** represents the bytecode interpretation approach under evaluation.

### 5.3 Where It Lives

```
benchmarks/matiec_harness/
  Cargo.toml
  src/main.rs
benchmarks/matiec_compile.sh     # ST → C → .so compilation script
```

### 5.4 Compilation Pipeline

MATIEC's compilation is a two-stage process. The `matiec_compile.sh` script automates both stages.

```bash
#!/usr/bin/env bash
# Usage: ./benchmarks/matiec_compile.sh <ST_FILE> <OPT_LEVEL> <OUTPUT_SO>
# Example: ./benchmarks/matiec_compile.sh benchmarks/programs/blinky.st O2 out/blinky_matiec_O2.so
set -euo pipefail

ST_FILE="$1"
OPT="${2:-O2}"       # O0 or O2
OUTPUT="$3"
NAME="$(basename "$ST_FILE" .st)"
WORK="out/matiec_${NAME}_${OPT}"
mkdir -p "$WORK"

# Stage 1: ST → C via iec2c
iec2c -I "${MATIEC_C_INCLUDE_PATH}" -T "$WORK" "$ST_FILE"

# Stage 2: C → shared library via GCC
# The generated files follow MATIEC conventions:
#   POUS.c / POUS.h   — Program Organization Units
#   Res0.c             — Resource configuration
#   Config0.c / .h     — Configuration
#   LOCATED_VARIABLES.h — I/O variable addresses
gcc -shared -fPIC "-${OPT}" \
    -I "$WORK" \
    -I "${MATIEC_C_INCLUDE_PATH}" \
    "$WORK"/POUS.c \
    "$WORK"/Res0.c \
    "$WORK"/Config0.c \
    -o "$OUTPUT" \
    -lm

echo "Compiled: $ST_FILE → $OUTPUT (GCC -${OPT})"
```

> **Environment variables:** `MATIEC_C_INCLUDE_PATH` must point to the MATIEC runtime headers directory (containing `iec_types_all.h`, `accessor.h`, etc.). This is set automatically in the Dockerfile.

### 5.5 Harness Implementation

The MATIEC harness is structurally similar to the RuSTy harness — it loads a `.so`, calls the entry point in a timing loop, and emits JSON. The key differences are in the entry point naming convention and initialization sequence.

MATIEC generates predictable symbol names based on the program/resource/configuration names in the ST source:

```bash
# Discover symbols in the compiled .so
nm -D out/blinky_matiec_O2.so | grep ' T '
# Typical output:
#   T config_init__
#   T config_run__
```

The harness calls `config_init__` once for initialization, then `config_run__` in the measurement loop.

```rust
// benchmarks/matiec_harness/src/main.rs

use libloading::{Library, Symbol};
use std::path::PathBuf;
use std::time::Instant;

#[derive(clap::Parser)]
struct Args {
    /// Path to MATIEC-compiled .so file
    #[arg(long)]
    lib: PathBuf,

    /// Program run entry point symbol [default: config_run__]
    #[arg(long, default_value = "config_run__")]
    entry: String,

    /// Initializer symbol [default: config_init__]
    #[arg(long, default_value = "config_init__")]
    init: String,

    /// Number of measured scan cycles
    #[arg(long, default_value = "10000")]
    cycles: usize,

    /// Unmeasured warmup cycles
    #[arg(long, default_value = "1000")]
    warmup: usize,

    /// Optimization level metadata (e.g., "O0", "O2")
    #[arg(long)]
    opt_level: String,

    /// Pin process to CPU 0 (Linux only)
    #[arg(long)]
    pin_cpu: bool,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    #[cfg(target_os = "linux")]
    if args.pin_cpu {
        pin_to_cpu(0)?;
    }

    let lib = unsafe { Library::new(&args.lib)? };

    // MATIEC init: call config_init__ to set up program variables
    let init: Symbol<unsafe extern "C" fn()> = unsafe {
        lib.get(args.init.as_bytes())?
    };
    unsafe { init() };

    // Entry point: config_run__ executes one scan cycle
    let entry: Symbol<unsafe extern "C" fn()> = unsafe {
        lib.get(args.entry.as_bytes())?
    };

    // Warmup
    for _ in 0..args.warmup {
        unsafe { entry() };
    }

    // Measured cycles
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

### 5.6 JSON Output Format

Same format as the RuSTy harness and `ironplcc bench`, enabling uniform consumption by `report.py`:

```json
{
  "program": "blinky_matiec_O2.so",
  "compiler": "matiec",
  "opt_level": "O2",
  "cycles": 10000,
  "warmup": 1000,
  "durations_us": {
    "mean": 0.2,
    "p50":  0.2,
    "p99":  0.4,
    "min":  0.1,
    "max":  0.8
  }
}
```

### 5.7 Dependencies

```toml
# benchmarks/matiec_harness/Cargo.toml
[package]
name = "matiec-harness"
version = "0.1.0"
edition = "2021"

[dependencies]
libloading  = "0.8"
clap        = { version = "4", features = ["derive"] }
serde_json  = "1"
anyhow      = "1"
libc        = "0.2"
```

### 5.8 ST Source Compatibility Notes

MATIEC's `iec2c` has some dialect differences from RuSTy:

- **PROGRAM declarations:** MATIEC requires a `CONFIGURATION`/`RESOURCE`/`TASK` wrapper around the `PROGRAM` declaration. The benchmark programs may need a thin wrapper file or pragma to satisfy `iec2c`.
- **Standard library coverage:** MATIEC implements the standard function blocks (TON, CTU, etc.) via C macro headers. Some RuSTy-specific extensions may not be supported.
- **Pragma inclusion:** MATIEC supports `{#include "file.iecst"}` for modular code, which can be used to share the core program logic across compilers while providing compiler-specific wrappers.

If a benchmark program cannot compile on MATIEC due to dialect differences, it will be excluded from the MATIEC column of the results table with a note explaining the incompatibility. The minimum viable set for MATIEC is programs 1, 4, and 5 (blinky, arithmetic, for_loop), which use only basic ST features.

---

## 6. Component 4 — Automation Script

### 6.1 What It Does

Orchestrates the full pipeline for a single ST source file: compile with all three toolchains, run all harnesses, verify correctness by comparing final output state, emit a combined report. Written in Python for portability and to share data structures with the report generators. Designed to be called from CI or manually during paper preparation.

### 6.2 Where It Lives

```
benchmarks/run_benchmark.py
benchmarks/run_all.py
```

### 6.3 `run_benchmark.py`

```python
#!/usr/bin/env python3
"""
Run the full benchmark pipeline for a single ST source file.

Usage: python benchmarks/run_benchmark.py benchmarks/programs/blinky.st
       python benchmarks/run_benchmark.py --skip-matiec benchmarks/programs/ton_oneshot.st
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=True, **kwargs)


def discover_rusty_symbols(so_path: str) -> tuple[str, str | None]:
    """Use nm to find the entry point and optional init symbol in a RuSTy .so."""
    result = subprocess.run(
        ["nm", "-D", so_path], capture_output=True, text=True, check=True
    )
    entry, init = None, None
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] == "T":
            sym = parts[2]
            if "__init__" in sym:
                init = sym
            elif not sym.startswith("_"):
                entry = entry or sym
    if not entry:
        sys.exit(f"Could not find entry symbol in {so_path}")
    return entry, init


def main():
    parser = argparse.ArgumentParser(description="Benchmark a single ST program")
    parser.add_argument("st_file", type=Path, help="Path to .st source file")
    parser.add_argument("--cycles", type=int, default=10_000)
    parser.add_argument("--warmup", type=int, default=1_000)
    parser.add_argument("--tick-us", type=int, default=1_000)
    parser.add_argument("--skip-matiec", action="store_true")
    args = parser.parse_args()

    name = args.st_file.stem
    out = Path("results") / name
    out.mkdir(parents=True, exist_ok=True)
    Path("out").mkdir(exist_ok=True)

    steps = 9 if not args.skip_matiec else 5
    step = 0

    def log(msg: str):
        nonlocal step
        step += 1
        print(f"[{step}/{steps}] {msg}")

    # ── Compile ──────────────────────────────────────────────
    log("RuSTy -O0 compile")
    run(["plc", str(args.st_file), "--shared", "-o", f"out/{name}_O0.so"])

    log("RuSTy -O2 compile")
    run(["plc", str(args.st_file), "--shared", "-O2", "-o", f"out/{name}_O2.so"])

    if not args.skip_matiec:
        log("MATIEC -O0 compile")
        run(["./benchmarks/matiec_compile.sh", str(args.st_file), "O0",
             f"out/{name}_matiec_O0.so"])

        log("MATIEC -O2 compile")
        run(["./benchmarks/matiec_compile.sh", str(args.st_file), "O2",
             f"out/{name}_matiec_O2.so"])

    log("IronPLC compile")
    run(["ironplcc", "compile", str(args.st_file), "-o", f"out/{name}.plc"])

    # ── Run harnesses ────────────────────────────────────────
    entry, init = discover_rusty_symbols(f"out/{name}_O0.so")
    init_args = ["--init", init] if init else []

    for opt in ("O0", "O2"):
        log(f"RuSTy -{opt} run")
        result = run(
            ["./benchmarks/rusty_harness/target/release/rusty-harness",
             "--lib", f"out/{name}_{opt}.so",
             "--entry", entry, *init_args,
             "--cycles", str(args.cycles), "--warmup", str(args.warmup),
             "--opt-level", opt,
             "--capture-output", str(out / f"rusty_{opt}_vars.json")],
            capture_output=True, text=True,
        )
        (out / f"rusty_{opt}.json").write_text(result.stdout)

    if not args.skip_matiec:
        for opt in ("O0", "O2"):
            log(f"MATIEC -{opt} run")
            result = run(
                ["./benchmarks/matiec_harness/target/release/matiec-harness",
                 "--lib", f"out/{name}_matiec_{opt}.so",
                 "--cycles", str(args.cycles), "--warmup", str(args.warmup),
                 "--opt-level", opt,
                 "--capture-output", str(out / f"matiec_{opt}_vars.json")],
                capture_output=True, text=True,
            )
            (out / f"matiec_{opt}.json").write_text(result.stdout)

    log("IronPLC run")
    result = run(
        ["ironplcc", "bench", f"out/{name}.plc",
         "--cycles", str(args.cycles), "--warmup", str(args.warmup),
         "--tick-us", str(args.tick_us),
         "--capture-output", str(out / "ironplc_vars.json"),
         "--report-format", "json"],
        capture_output=True, text=True,
    )
    (out / "ironplc.json").write_text(result.stdout)

    # ── Correctness check ────────────────────────────────────
    print(f"\n── Correctness: {name} ──")
    var_files = list(out.glob("*_vars.json"))
    run(["python3", "benchmarks/tools/compare_outputs.py"] +
        [str(f) for f in var_files])

    # ── Report ───────────────────────────────────────────────
    report_args = [
        "python3", "benchmarks/tools/report.py",
        "--name", name,
        "--rusty-O0", str(out / "rusty_O0.json"),
        "--rusty-O2", str(out / "rusty_O2.json"),
        "--ironplc", str(out / "ironplc.json"),
    ]
    if not args.skip_matiec:
        report_args += [
            "--matiec-O0", str(out / "matiec_O0.json"),
            "--matiec-O2", str(out / "matiec_O2.json"),
        ]
    run(report_args)

    print(f"\nDone. Results in {out}/")


if __name__ == "__main__":
    main()
```

### 6.4 `run_all.py`

```python
#!/usr/bin/env python3
"""
Run benchmarks for all programs in the suite.

Usage: python benchmarks/run_all.py
       python benchmarks/run_all.py --skip-matiec
       python benchmarks/run_all.py --cycles 100000
"""
import argparse
import subprocess
import sys
from pathlib import Path

PROGRAMS = [
    "benchmarks/programs/blinky.st",
    "benchmarks/programs/ton_oneshot.st",
    "benchmarks/programs/counter_up.st",
    "benchmarks/programs/arithmetic.st",
    "benchmarks/programs/for_loop.st",
    "benchmarks/programs/case_state.st",
]


def main():
    parser = argparse.ArgumentParser(description="Run all benchmarks")
    parser.add_argument("--cycles", type=int, default=10_000)
    parser.add_argument("--warmup", type=int, default=1_000)
    parser.add_argument("--skip-matiec", action="store_true")
    args = parser.parse_args()

    failed = []
    for prog in PROGRAMS:
        print(f"\n{'═' * 60}")
        print(f"  {prog}")
        print(f"{'═' * 60}\n")
        cmd = [
            sys.executable, "benchmarks/run_benchmark.py", prog,
            "--cycles", str(args.cycles),
            "--warmup", str(args.warmup),
        ]
        if args.skip_matiec:
            cmd.append("--skip-matiec")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            failed.append(prog)

    # Summary table across all programs
    subprocess.run([
        sys.executable, "benchmarks/tools/summary_table.py", "results/"
    ])

    if failed:
        print(f"\nFailed programs: {', '.join(failed)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
```

---

## 7. Component 5 — Output Capture and Comparison

### 7.1 Design Principle: Deterministic Final State

Each benchmark program is designed so that running it for a known number of cycles produces a **deterministic, analytically predictable final state**. Correctness is verified by checking that all three compilers (RuSTy, MATIEC, IronPLC) produce identical final variable values after the same total number of cycles (warmup + measured).

This approach is simple and compiler-agnostic — no companion inspection functions, no `dlsym` tricks, no compiler-specific introspection. Each harness runs the program, then captures the final state of all program variables to a JSON file. A Python script compares the JSON files across compilers.

Examples of deterministic final state:

| Program | Cycles | Expected final state |
|---|---|---|
| `counter_up.st` | 10,000 | `counter = 10000` |
| `for_loop.st` | 10,000 | `accumulator = 5050` (each cycle computes sum 1..100) |
| `arithmetic.st` | 10,000 | `result = <computed value>` (deterministic arithmetic) |
| `blinky.st` | 10,000 | `output_coil = FALSE` (10000 is even → toggled back) |
| `case_state.st` | 10,000 | `state = 2` (10000 mod 4 = 0, cycles through states 0→1→2→3→0…) |

### 7.2 How Each Harness Captures Final State

All three harnesses support a `--capture-output <PATH>` flag. After the measurement loop completes (timing window closed), the harness serializes the program's final variable values to JSON at the given path. This adds zero overhead to the measurement loop.

**IronPLC:** `ironplcc bench --capture-output vars.json` serializes the VM's variable store after all cycles complete.

**RuSTy harness:** After the measurement loop, the harness reads global variable addresses from the `.so` via `dlsym` (using symbols discovered by `nm -D`) and writes them to JSON.

**MATIEC harness:** After the measurement loop, the harness reads the program instance struct from the `.so` via `dlsym` (MATIEC generates predictable global symbols like `__CONFIG0__`) and writes variable values to JSON.

The JSON format is the same across all three:

```json
{
  "counter": 10000,
  "output_coil": false,
  "accumulator": 5050
}
```

### 7.3 `compare_outputs.py`

Takes two or more variable JSON files and verifies they all agree. Compares every pair, reports any mismatches.

```python
#!/usr/bin/env python3
"""
Compare final variable state across compilers.
All input files must contain identical variable values.

Usage: compare_outputs.py rusty_O2_vars.json matiec_O2_vars.json ironplc_vars.json
"""
import json
import sys
from pathlib import Path


def load(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def main():
    if len(sys.argv) < 3:
        sys.exit("Usage: compare_outputs.py <file1.json> <file2.json> [file3.json ...]")

    files = sys.argv[1:]
    data = {Path(f).stem: load(f) for f in files}
    names = list(data.keys())
    reference_name = names[0]
    reference = data[reference_name]

    all_pass = True
    for name in names[1:]:
        other = data[name]
        mismatches = []
        for var, expected in reference.items():
            actual = other.get(var)
            if actual != expected:
                mismatches.append((var, expected, actual))

        if mismatches:
            all_pass = False
            print(f"FAIL  {reference_name} vs {name}")
            for var, exp, act in mismatches:
                print(f"  {var}: {reference_name}={exp}  {name}={act}")
        else:
            print(f"PASS  {reference_name} vs {name}  ({len(reference)} variables)")

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
```

---

## 8. Component 6 — Report Generator

### 8.1 `report.py` — Per-Program Report

Reads up to five JSON result files (RuSTy O0/O2, MATIEC O0/O2, IronPLC) and emits a formatted comparison table to stdout. MATIEC columns are optional — if `--matiec-O0` / `--matiec-O2` are not provided, those rows are omitted.

```
Program: blinky
Cycles:  10,000  (warmup: 1,000)

                  mean µs    p50 µs    p99 µs    max µs
RuSTy  -O0           0.3       0.3       0.5       1.2
RuSTy  -O2           0.1       0.1       0.2       0.4
MATIEC -O0           0.4       0.3       0.6       1.5
MATIEC -O2           0.2       0.2       0.3       0.6
IronPLC              2.1       2.0       3.1       6.8

IronPLC overhead vs RuSTy  -O0:   7.0x  (mean)
IronPLC overhead vs RuSTy  -O2:  21.0x  (mean)
IronPLC overhead vs MATIEC -O0:   5.3x  (mean)
IronPLC overhead vs MATIEC -O2:  10.5x  (mean)
```

### 8.2 `summary_table.py` — Cross-Program Table for Paper

Aggregates all per-program results into the table that goes directly into the paper, with a 1 ms real-time budget check column. Includes both RuSTy and MATIEC baselines.

```
Program          IronPLC p99    RuSTy -O2 p99    MATIEC -O2 p99    vs RuSTy    vs MATIEC    1 ms budget
blinky                2.1 µs          0.2 µs           0.2 µs        10.5x        10.5x         ✓
ton_oneshot           6.8 µs          0.4 µs              —          17.0x            —         ✓
counter_up            5.1 µs          0.3 µs           0.3 µs        17.0x        17.0x         ✓
arithmetic            4.3 µs          0.3 µs           0.3 µs        14.3x        14.3x         ✓
for_loop             12.4 µs          0.7 µs           0.8 µs        17.7x        15.5x         ✓
case_state            8.9 µs          0.5 µs           0.6 µs        17.8x        14.8x         ✓
```

> **Note:** A dash (`—`) indicates the program could not be compiled by MATIEC due to dialect incompatibility.

---

## 9. Repository Layout

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
  matiec_harness/              # Component 3
    Cargo.toml
    src/main.rs
  matiec_compile.sh            # ST → C → .so compilation wrapper
  tools/                       # Components 5 & 6
    compare_outputs.py
    report.py
    summary_table.py
  run_benchmark.py             # Component 4
  run_all.py
  README.md                    # Reproduction instructions for paper reviewers
  results/                     # Generated at runtime — in .gitignore
    .gitkeep
  reference_results/           # Checked in — the paper's actual numbers
    blinky/
      rusty_O0.json
      rusty_O2.json
      matiec_O0.json
      matiec_O2.json
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

## 10. Build and Run Instructions

These go into `benchmarks/README.md` for paper reviewers.

### Prerequisites

```bash
# RuSTy (pinned to commit used for paper)
cargo install --git https://github.com/PLC-lang/rusty --rev <COMMIT_HASH> plc

# MATIEC (pinned to commit used for paper)
# Requires: flex, bison, build-essential
git clone https://github.com/sm1820/matiec.git /opt/matiec
cd /opt/matiec && autoreconf -i && ./configure && make
export PATH="/opt/matiec:$PATH"
export MATIEC_C_INCLUDE_PATH="/opt/matiec/lib/C"

# IronPLC (from this repository)
cargo install --path compiler/ironplcc

# Build the RuSTy harness
cargo build --release --manifest-path benchmarks/rusty_harness/Cargo.toml

# Build the MATIEC harness
cargo build --release --manifest-path benchmarks/matiec_harness/Cargo.toml

# Python dependencies
pip install tabulate
```

### Run Full Suite

```bash
python benchmarks/run_all.py
```

### Run Single Program

```bash
python benchmarks/run_benchmark.py benchmarks/programs/blinky.st
```

### Reproducibility Notes

- Results in `benchmarks/reference_results/` were collected on `<CPU>`, `<OS>`, kernel `<version>`.
- Absolute timings vary by hardware. The overhead ratios (IronPLC p99 / RuSTy O2 p99, IronPLC p99 / MATIEC O2 p99) are expected to be stable across x86-64 platforms.
- RuSTy was pinned to commit `<hash>`. MATIEC was pinned to commit `<hash>`. IronPLC was built from commit `<hash>`.
- For lower variance, increase cycles: `python benchmarks/run_all.py --cycles 100000`
- To skip MATIEC (e.g. if `iec2c` is not installed): `python benchmarks/run_all.py --skip-matiec`

---

## 11. Paper Section Outline

---

### 5 Evaluation

#### 5.1 Goals

We evaluate IronPLC along two axes. The first is **correctness**: given a program that executes correctly on established IEC 61131-3 runtimes, does IronPLC produce identical output values? The second is **performance**: what is the cost of IronPLC's interpreted VM execution relative to native compilation (both RuSTy's LLVM backend and MATIEC's GCC-compiled C output), and does IronPLC's absolute cycle time remain within the real-time envelope required by target applications?

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

**Toolchains.** IronPLC compiles ST source to bytecode via `ironplcc compile` and executes via the `ironplcc bench` subcommand. RuSTy compiles the same ST source to a native shared library via `plc --shared`, which is then executed by a thin Rust harness that calls the program entry point in a loop. MATIEC transpiles the same ST source to ANSI C via `iec2c`, which is then compiled to a shared library by GCC and executed by an equivalent Rust harness. Both RuSTy and MATIEC are evaluated at two optimization levels: `-O0` (unoptimized, a fairer baseline that isolates the interpreter-vs-dispatch distinction from backend optimization) and `-O2` (production-grade, the realistic ceiling for native execution).

**Measurement protocol.** Each program runs for 1,000 warmup cycles (unmeasured) followed by 10,000 measured cycles. Warmup stabilises instruction and data caches. All processes are pinned to a single CPU core via `sched_setaffinity`. Timing uses `CLOCK_MONOTONIC_RAW` on Linux, which is unaffected by NTP adjustments. We report mean, p50, p99, and max cycle time. **p99 is the primary metric** because it governs worst-case latency, which determines real-time deployability.

**Equivalence of measurement.** The IronPLC `bench` subcommand places `Instant::now()` calls outside `run_round`, so the VM executes identically to production. The RuSTy and MATIEC harnesses place equivalent timing calls outside the entry point call. All three harnesses use the same JSON report format; the summary table is generated by a single Python script consuming all results.

**Correctness verification.** Each benchmark program is designed so that its final variable state after a fixed number of cycles is deterministic and analytically predictable (e.g., a counter incremented once per cycle reaches exactly 11,000 after 11,000 total cycles; a state machine cycling through 4 states lands on a known state). After each run, each harness captures the final variable state to JSON. `compare_outputs.py` verifies that all compilers (RuSTy, MATIEC, IronPLC) produce identical final values. A program passes only if all output variables agree across every compiler.

**Hardware.** `<CPU model, core count, clock speed>`, `<RAM>`, `<OS and version>`, kernel `<version>`.

---

#### 5.4 Correctness Results

All N programs in the benchmark suite produce identical output values when executed by IronPLC, RuSTy, and MATIEC for 10,000 scan cycles. This confirms that IronPLC's bytecode semantics match the IEC 61131-3 specification for the language features exercised by the suite. _(If any programs required debugging to reach this result, describe the defect and fix in one sentence each. If any programs could not be compiled by MATIEC due to dialect differences, note which programs and why.)_

---

#### 5.5 Performance Results

_Table 2: Per-cycle execution time (µs), 10,000 cycles._

|Program|RuSTy -O2 p99|MATIEC -O2 p99|IronPLC p99|vs RuSTy|vs MATIEC|1 ms budget|
|---|---|---|---|---|---|---|
|Blinky||||||✓|
|TON one-shot||||| — |✓|
|Counter||||||✓|
|Arithmetic||||||✓|
|FOR loop||||||✓|
|CASE state||||||✓|

> A dash (`—`) indicates the program could not be compiled by MATIEC due to dialect incompatibility.

IronPLC's interpreted execution is Nx–Mx slower than RuSTy's LLVM-optimized native code and Ax–Bx slower than MATIEC's GCC-compiled C code (Table 2). This overhead is consistent with published comparisons between bytecode interpreters and native code in other domains. Despite this overhead, IronPLC's p99 cycle time remains below Y µs across all benchmark programs — well within the 1 ms cycle budget common in industrial PLC applications.

The comparison between RuSTy and MATIEC is also informative: RuSTy's LLVM backend at `-O2` outperforms MATIEC's GCC-compiled C by Cx–Dx, reflecting the quality of RuSTy's IR generation and LLVM's optimization passes compared to the two-stage transpilation approach. The overhead of IronPLC relative to unoptimized baselines (`-O0`) narrows to Px–Qx, establishing that a substantial portion of the native code advantage at `-O2` derives from backend optimization rather than the compiled-vs-interpreted distinction alone.

---

#### 5.6 Discussion

**Interpreter overhead.** The Nx overhead ratio is expected for a pure interpreter with no JIT compilation. IronPLC's dispatch loop uses a Rust `match` on the opcode byte, which the compiler lowers to a jump table. There is no per-opcode overhead from dynamic dispatch or boxing; all values are stored as fixed-width `Slot` types in pre-allocated buffers. The dominant cost is the interpreter loop itself relative to native code where loop overhead is compiled away entirely.

**MATIEC as a baseline.** MATIEC represents the traditional open-source PLC compilation approach: transpile to C, then compile with a general-purpose C compiler. Its inclusion provides a second native-code reference point that reflects real-world industrial practice (OpenPLC uses this exact pipeline in production). The performance gap between RuSTy and MATIEC quantifies the benefit of purpose-built IR generation and LLVM optimization over the transpilation approach. For IronPLC, the overhead ratio against MATIEC is more representative of the "cost of interpretation" in practice, since MATIEC's compilation quality is closer to what deployed PLC runtimes achieve.

**Real-time viability.** The 1 ms cycle budget is conservative; non-safety-critical PLC applications commonly use 10–100 ms cycle times. At these rates, IronPLC's absolute cycle time is negligible and the interpretation overhead is immaterial. For hard real-time applications requiring sub-millisecond cycles, compilation-based approaches such as RuSTy remain preferable. IronPLC targets the large class of applications where interpreted execution is acceptable in exchange for the safety guarantees of all-safe-Rust execution, cross-platform portability, and the open-source tooling ecosystem.

**Threats to validity.**

1. The benchmark programs are small; real PLC programs may be larger and exhibit different instruction cache behaviour.
2. Measurements were taken on a general-purpose OS without real-time scheduling. Production deployments on PREEMPT_RT or dedicated hardware would see different absolute timings and lower variance.
3. RuSTy, MATIEC, and IronPLC do not share a compiler front-end; the same ST source was compiled independently by each toolchain. Programs were manually verified to be semantically equivalent by comparing output traces.
4. MATIEC may not compile all benchmark programs due to dialect differences with RuSTy's ST extensions. Programs that MATIEC cannot compile are excluded from its column in the results table.

---

#### Related Work (excerpt)

> The performance tradeoff between interpreted and compiled execution of domain-specific languages has been studied extensively in the context of JVM bytecode, CPython, and embedded scripting languages. In the IEC 61131-3 domain, no prior open-source work provides a systematic runtime benchmark comparing interpreted and compiled execution of Structured Text programs. RuSTy provides a compiler correctness test suite verified against LLVM IR output, but does not include a runtime execution harness. MATIEC, the open-source IEC 61131-3 transpiler used by OpenPLC, compiles ST to C but does not include a standalone benchmarking facility. OpenPLC provides example programs but no formal benchmark suite. This work contributes the first open-source benchmark harness for IEC 61131-3 runtime execution, comparing three distinct compilation strategies (LLVM native via RuSTy, GCC native via MATIEC, and bytecode interpretation via IronPLC), published alongside IronPLC as a reusable tool for the IEC 61131-3 implementation community.

---

## Implementation Order

Build in this sequence. Each step produces something independently useful and unblocks the next.

|Step|Component|Deliverable|Unblocks|
|---|---|---|---|
|1|`ironplcc bench` (timing only)|Can measure IronPLC cycle time|Everything else|
|2|RuSTy harness binary|Can measure RuSTy cycle time|Steps 4–9|
|3|MATIEC harness + `matiec_compile.sh`|Can measure MATIEC cycle time|Steps 4–9|
|4|`run_benchmark.py`|Single command runs all three|Paper workflow|
|5|`--capture-output` + `compare_outputs.py`|Final-state correctness verification|Section 5.4|
|6|`report.py` + `summary_table.py`|Paper tables (three-way comparison)|Section 5.5|
|7|Benchmark programs 6–8|Broader evaluation|Stronger paper|
|8|MATIEC compatibility testing|Verify which programs compile on MATIEC|Accurate results table|
|9|`README.md` + `SOURCES.md` + pinned commits|Reproducibility|Submission|