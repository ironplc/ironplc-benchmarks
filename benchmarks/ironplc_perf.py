#!/usr/bin/env python3
"""
IronPLC performance testing script.

Compiles ST programs with ironplcc, benchmarks with ironplcvm, and compares
results across runs. Designed for a try-test loop: save a baseline, make
changes to IronPLC, then compare.

Usage:
    # Run and print results
    python benchmarks/ironplc_perf.py

    # Save a named baseline
    python benchmarks/ironplc_perf.py --save-baseline before

    # Compare current performance against a saved baseline
    python benchmarks/ironplc_perf.py --compare before

    # Run specific programs
    python benchmarks/ironplc_perf.py --programs oscat_binom oscat_gcd

    # More cycles for stable results
    python benchmarks/ironplc_perf.py --cycles 50000 --warmup 5000
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROGRAMS_DIR = Path("benchmarks/programs")
PERF_DIR = Path("perf")
DEFAULT_CYCLES = 10000
DEFAULT_WARMUP = 1000


def find_programs(names: list[str] | None) -> list[Path]:
    """Find ST files to benchmark."""
    all_st = sorted(PROGRAMS_DIR.glob("*.st"))
    if names:
        st_files = [f for f in all_st if f.stem in names]
        if not st_files:
            print(f"No matching programs: {names}")
            print(f"Available: {[f.stem for f in all_st]}")
            sys.exit(1)
        return st_files
    return all_st


def compile_program(st_path: Path, out_dir: Path) -> Path | None:
    """Compile a single ST file with ironplcc. Returns .iplc path or None."""
    iplc = out_dir / f"{st_path.stem}.iplc"
    r = subprocess.run(
        ["ironplcc", "compile", str(st_path), "-o", str(iplc)],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        return None
    return iplc


def benchmark_program(iplc_path: Path, cycles: int, warmup: int) -> dict | None:
    """Run ironplcvm benchmark and return parsed JSON result."""
    r = subprocess.run(
        [
            "ironplcvm",
            "benchmark",
            str(iplc_path),
            "--cycles",
            str(cycles),
            "--warmup",
            str(warmup),
        ],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)


def run_benchmarks(st_files: list[Path], cycles: int, warmup: int) -> dict[str, dict]:
    """Compile and benchmark all programs. Returns {name: result}."""
    out_dir = PERF_DIR / "tmp"
    out_dir.mkdir(parents=True, exist_ok=True)

    results = {}
    for st in st_files:
        name = st.stem
        iplc = compile_program(st, out_dir)
        if not iplc:
            print(f"  {name:30s} compile FAILED")
            continue

        result = benchmark_program(iplc, cycles, warmup)
        if not result:
            print(f"  {name:30s} benchmark FAILED")
            continue

        scan = result.get("scan_us", {})
        results[name] = {
            "mean": scan.get("mean", 0.0),
            "p99": scan.get("p99", 0.0),
            "max": scan.get("max", 0.0),
            "stddev": scan.get("stddev", 0.0),
            "cycles": cycles,
            "warmup": warmup,
        }
        print(
            f"  {name:30s} "
            f"mean={scan['mean']:8.3f}µs  "
            f"p99={scan['p99']:8.3f}µs  "
            f"max={scan['max']:8.3f}µs"
        )

    # Clean up temp files
    shutil.rmtree(out_dir, ignore_errors=True)
    return results


def save_baseline(results: dict[str, dict], name: str) -> Path:
    """Save results as a named baseline."""
    baselines_dir = PERF_DIR / "baselines"
    baselines_dir.mkdir(parents=True, exist_ok=True)
    path = baselines_dir / f"{name}.json"
    path.write_text(json.dumps(results, indent=2) + "\n")
    return path


def load_baseline(name: str) -> dict[str, dict]:
    """Load a named baseline."""
    path = PERF_DIR / "baselines" / f"{name}.json"
    if not path.exists():
        print(f"Baseline '{name}' not found at {path}")
        saved = list((PERF_DIR / "baselines").glob("*.json"))
        if saved:
            print(f"Available: {[f.stem for f in saved]}")
        sys.exit(1)
    return json.loads(path.read_text())


def print_comparison(baseline: dict[str, dict], current: dict[str, dict]):
    """Print side-by-side comparison with deltas."""
    all_names = sorted(set(baseline) | set(current))

    print(
        f"  {'Program':30s} "
        f"{'baseline':>10s} "
        f"{'current':>10s} "
        f"{'change':>10s} "
        f"{'ratio':>8s}"
    )
    print("  " + "-" * 72)

    for name in all_names:
        base = baseline.get(name)
        curr = current.get(name)

        if not base and not curr:
            continue

        if not base:
            print(f"  {name:30s} {'—':>10s} {curr['mean']:9.3f}µs {'(new)':>10s}")
            continue

        if not curr:
            print(f"  {name:30s} {base['mean']:9.3f}µs {'—':>10s} {'(gone)':>10s}")
            continue

        base_mean = base["mean"]
        curr_mean = curr["mean"]

        if base_mean > 0:
            ratio = curr_mean / base_mean
            pct = (ratio - 1.0) * 100.0

            if abs(pct) < 2.0:
                status = "~"
            elif pct < 0:
                status = f"{pct:+.1f}%"
            else:
                status = f"{pct:+.1f}%"

            print(
                f"  {name:30s} "
                f"{base_mean:9.3f}µs "
                f"{curr_mean:9.3f}µs "
                f"{status:>10s} "
                f"{ratio:7.2f}x"
            )
        else:
            print(f"  {name:30s} {base_mean:9.3f}µs {curr_mean:9.3f}µs")


def main():
    parser = argparse.ArgumentParser(description="IronPLC performance testing")
    parser.add_argument(
        "--cycles",
        type=int,
        default=DEFAULT_CYCLES,
        help=f"Measured scan cycles (default: {DEFAULT_CYCLES})",
    )
    parser.add_argument(
        "--warmup",
        type=int,
        default=DEFAULT_WARMUP,
        help=f"Warmup cycles (default: {DEFAULT_WARMUP})",
    )
    parser.add_argument(
        "--programs",
        nargs="*",
        help="Program names to benchmark (default: all)",
    )
    parser.add_argument(
        "--save-baseline",
        metavar="NAME",
        help="Save results as a named baseline",
    )
    parser.add_argument(
        "--compare",
        metavar="NAME",
        help="Compare current results against a saved baseline",
    )
    args = parser.parse_args()

    # Check tools
    for tool in ("ironplcc", "ironplcvm"):
        if not shutil.which(tool):
            print(f"ERROR: {tool} not found on PATH")
            sys.exit(1)

    st_files = find_programs(args.programs)
    print(f"Programs: {', '.join(f.stem for f in st_files)}")
    print(f"Cycles: {args.cycles}  Warmup: {args.warmup}")
    print()

    print("Running benchmarks...")
    results = run_benchmarks(st_files, args.cycles, args.warmup)
    print()

    if not results:
        print("No programs compiled successfully.")
        sys.exit(1)

    if args.save_baseline:
        path = save_baseline(results, args.save_baseline)
        print(f"Baseline saved: {path}")
        print()

    if args.compare:
        baseline = load_baseline(args.compare)
        print(f"Comparison against '{args.compare}':")
        print_comparison(baseline, results)
        print()


if __name__ == "__main__":
    main()
