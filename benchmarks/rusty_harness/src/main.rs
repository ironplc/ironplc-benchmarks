use std::path::PathBuf;
use std::time::Instant;

use anyhow::{Context, Result};
use clap::Parser;
use libloading::{Library, Symbol};
use serde::Serialize;

/// Benchmark harness for RuSTy-compiled IEC 61131-3 shared libraries.
///
/// Loads a shared object produced by `plc --shared`, calls the program entry
/// point for a configurable number of scan cycles, and emits a JSON timing
/// report compatible with `ironplcc bench`.
///
/// RuSTy compiles each PROGRAM to a function that takes a pointer to an
/// instance struct (e.g. `blinky(*mut blinky_instance)`). The harness looks
/// up both the entry point and the instance symbol via dlsym.
#[derive(Parser)]
#[command(name = "rusty-harness")]
struct Args {
    /// Path to the RuSTy-compiled shared library (.so)
    #[arg(long)]
    lib: PathBuf,

    /// Symbol name of the program entry point (e.g. "blinky")
    #[arg(long)]
    entry: String,

    /// Symbol name of the program instance global (e.g. "blinky_instance")
    #[arg(long)]
    instance: String,

    /// Symbol name of the initializer function (e.g. "__init___blinky_st")
    #[arg(long)]
    init: Option<String>,

    /// Number of measured scan cycles
    #[arg(long, default_value = "10000")]
    cycles: usize,

    /// Number of unmeasured warmup cycles
    #[arg(long, default_value = "1000")]
    warmup: usize,

    /// Optimization level used to compile the .so (metadata only, e.g. "O0")
    #[arg(long, default_value = "O0")]
    opt_level: String,

    /// Pin process to CPU 0 (Linux only)
    #[arg(long)]
    pin_cpu: bool,
}

#[derive(Serialize)]
struct BenchReport {
    program: String,
    opt_level: String,
    cycles: usize,
    warmup: usize,
    durations_us: DurationStats,
}

#[derive(Serialize)]
struct DurationStats {
    mean: f64,
    p50: f64,
    p99: f64,
    min: f64,
    max: f64,
}

fn main() -> Result<()> {
    let args = Args::parse();

    #[cfg(target_os = "linux")]
    if args.pin_cpu {
        pin_to_cpu(0)?;
    }

    // Safety: we are loading a shared library produced by the RuSTy compiler.
    // The caller is responsible for providing a valid .so with the declared symbols.
    let lib = unsafe {
        Library::new(&args.lib)
            .with_context(|| format!("Failed to load library: {}", args.lib.display()))?
    };

    // Look up the program instance global. RuSTy compiles each PROGRAM to a
    // function that takes a pointer to its instance struct (containing all
    // VAR declarations). The instance is a global symbol in the .so.
    let instance_ptr: *mut u8 = unsafe {
        let sym: Symbol<*mut u8> = lib
            .get(args.instance.as_bytes())
            .with_context(|| format!("Instance symbol not found: {}", args.instance))?;
        *sym
    };

    // Call the initializer if provided. RuSTy emits __init___<filename>_st
    // which internally finds the instance and initializes variables.
    if let Some(ref init_sym) = args.init {
        let init: Symbol<unsafe extern "C" fn()> = unsafe {
            lib.get(init_sym.as_bytes())
                .with_context(|| format!("Init symbol not found: {init_sym}"))?
        };
        unsafe { init() };
    }

    // RuSTy entry points take a pointer to the instance struct.
    let entry: Symbol<unsafe extern "C" fn(*mut u8)> = unsafe {
        lib.get(args.entry.as_bytes())
            .with_context(|| format!("Entry symbol not found: {}", args.entry))?
    };

    // Warmup — not measured; allows caches to stabilize
    for _ in 0..args.warmup {
        unsafe { entry(instance_ptr) };
    }

    // Measured cycles — pre-allocate to avoid heap allocation during measurement
    let mut durations_ns: Vec<u64> = Vec::with_capacity(args.cycles);
    for _ in 0..args.cycles {
        let t0 = Instant::now();
        unsafe { entry(instance_ptr) };
        durations_ns.push(t0.elapsed().as_nanos() as u64);
    }

    let report = compute_report(&args, &mut durations_ns);
    println!(
        "{}",
        serde_json::to_string_pretty(&report).context("Failed to serialize report")?
    );

    Ok(())
}

fn compute_report(args: &Args, durations_ns: &mut [u64]) -> BenchReport {
    durations_ns.sort_unstable();
    let n = durations_ns.len();
    let sum: u64 = durations_ns.iter().sum();

    BenchReport {
        program: args.lib.display().to_string(),
        opt_level: args.opt_level.clone(),
        cycles: args.cycles,
        warmup: args.warmup,
        durations_us: DurationStats {
            mean: (sum as f64 / n as f64) / 1_000.0,
            p50: durations_ns[n * 50 / 100] as f64 / 1_000.0,
            p99: durations_ns[n * 99 / 100] as f64 / 1_000.0,
            min: durations_ns[0] as f64 / 1_000.0,
            max: durations_ns[n - 1] as f64 / 1_000.0,
        },
    }
}

#[cfg(target_os = "linux")]
fn pin_to_cpu(cpu: usize) -> Result<()> {
    use std::mem;

    unsafe {
        let mut set: libc::cpu_set_t = mem::zeroed();
        libc::CPU_ZERO(&mut set);
        libc::CPU_SET(cpu, &mut set);
        let ret = libc::sched_setaffinity(0, mem::size_of::<libc::cpu_set_t>(), &set);
        if ret != 0 {
            anyhow::bail!("sched_setaffinity failed: {}", std::io::Error::last_os_error());
        }
    }
    Ok(())
}
