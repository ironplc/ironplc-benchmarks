#!/usr/bin/env python3
"""
End-to-end benchmark pipeline.

Builds harnesses, discovers available compilers, compiles all ST programs,
runs benchmarks, validates JSON output format, and compares results.
Works identically locally and in CI.

Usage:
    python benchmarks/run_e2e.py                    # default 1000 cycles
    python benchmarks/run_e2e.py --cycles 10000     # more cycles
    python benchmarks/run_e2e.py --programs blinky   # single program
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

# ── Defaults ────────────────────────────────────────────────────────

DEFAULT_CYCLES = 1000
DEFAULT_WARMUP = 100
PROGRAMS_DIR = Path("benchmarks/programs")
OUT_DIR = Path("out")
RESULTS_DIR = Path("results")

RUSTY_HARNESS = Path("benchmarks/rusty_harness/target/release/rusty-harness")
MATIEC_HARNESS = Path("benchmarks/matiec_harness/target/release/matiec-harness")
MATIEC_COMPILE = Path("benchmarks/matiec_compile.sh")


# ── Helpers ─────────────────────────────────────────────────────────


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run a command, print it, and return the result."""
    print(f"    $ {' '.join(cmd)}")
    return subprocess.run(cmd, **kwargs)


def has_tool(name: str) -> bool:
    return shutil.which(name) is not None


def discover_rusty_symbols(so_path: Path) -> tuple[str, str | None, str | None]:
    """Find entry, init, and instance symbols in a RuSTy .so via nm.

    Returns (entry, init, instance) where entry is the program function,
    init is the __init___<name>_st initializer, and instance is the
    <name>_instance global that must be passed as the first argument.
    """
    result = subprocess.run(
        ["nm", "-D", str(so_path)], capture_output=True, text=True, check=True
    )
    entry, init, instance = None, None, None
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3:
            sym = parts[2]
            if parts[1] == "T":
                if "__init__" in sym:
                    init = sym
                elif not sym.startswith("_"):
                    entry = entry or sym
            elif parts[1] in ("B", "D") and sym.endswith("_instance"):
                instance = sym
    return entry, init, instance


# ── Pipeline stages ─────────────────────────────────────────────────


HARNESSES = [
    ("rusty-harness", Path("benchmarks/rusty_harness")),
    ("matiec-harness", Path("benchmarks/matiec_harness")),
]


def build_harnesses() -> None:
    """Build Rust harnesses from source if the binary is missing but Cargo.toml exists."""
    for name, crate_dir in HARNESSES:
        cargo_toml = crate_dir / "Cargo.toml"
        binary = crate_dir / "target" / "release" / name
        if binary.exists():
            print(f"  {name:20s} already built")
            continue
        if not cargo_toml.exists():
            print(f"  {name:20s} no Cargo.toml — skipping")
            continue
        print(f"  {name:20s} building...")
        r = run(
            ["cargo", "build", "--release", "--manifest-path", str(cargo_toml)],
        )
        if r.returncode != 0:
            print(f"  WARN: failed to build {name}")
        else:
            print(f"  {name:20s} done")
    print()


def discover_environment() -> dict:
    """Detect which compilers and harnesses are available."""
    env = {
        "plc": has_tool("plc"),
        "iec2c": has_tool("iec2c") and MATIEC_COMPILE.exists(),
        "ironplcc": has_tool("ironplcc"),
        "rusty_harness": RUSTY_HARNESS.exists(),
        "matiec_harness": MATIEC_HARNESS.exists(),
    }

    print("Environment:")
    for name, available in env.items():
        status = "found" if available else "not found"
        print(f"  {name:20s} {status}")
    print()

    if not env["plc"]:
        print("ERROR: plc (RuSTy) is required but not found on PATH")
        sys.exit(1)
    if not env["rusty_harness"]:
        print(
            f"ERROR: {RUSTY_HARNESS} not found — run: cargo build --release "
            f"--manifest-path benchmarks/rusty_harness/Cargo.toml"
        )
        sys.exit(1)

    return env


def compile_programs(st_files: list[Path], env: dict) -> dict[str, list[Path]]:
    """Compile each ST file with every available compiler. Returns {program: [so_paths]}."""
    OUT_DIR.mkdir(exist_ok=True)
    compiled: dict[str, list[Path]] = {}

    for st in st_files:
        name = st.stem
        compiled[name] = []
        print(f"  Compile: {name}")

        # RuSTy — plc uses -O none / -O default (not -O0 / -O2)
        OPT_FLAGS = {"O0": ["-O", "none"], "O2": ["-O", "default"]}
        for opt in ("O0", "O2"):
            so = OUT_DIR / f"{name}_{opt}.so"
            cmd = ["plc", str(st), "--shared", *OPT_FLAGS[opt], "-o", str(so)]
            r = run(cmd)
            if r.returncode == 0:
                compiled[name].append(so)
            else:
                print(f"    FAIL: RuSTy -{opt}")

        # MATIEC
        if env["iec2c"]:
            for opt in ("O0", "O2"):
                so = OUT_DIR / f"{name}_matiec_{opt}.so"
                r = run(
                    [str(MATIEC_COMPILE), str(st), opt, str(so)],
                )
                if r.returncode == 0:
                    compiled[name].append(so)
                else:
                    print(f"    SKIP: MATIEC -{opt} (incompatible)")

        # IronPLC
        if env["ironplcc"]:
            plc_file = OUT_DIR / f"{name}.plc"
            r = run(["ironplcc", "compile", str(st), "-o", str(plc_file)])
            if r.returncode == 0:
                compiled[name].append(plc_file)
            else:
                print("    FAIL: IronPLC compile")

        print()

    return compiled


def run_benchmarks(
    st_files: list[Path], env: dict, cycles: int, warmup: int
) -> list[Path]:
    """Execute benchmarks and write JSON results. Returns list of result files."""
    result_files: list[Path] = []

    for st in st_files:
        name = st.stem
        result_dir = RESULTS_DIR / name
        result_dir.mkdir(parents=True, exist_ok=True)
        print(f"  Run: {name}")

        # RuSTy
        o0_so = OUT_DIR / f"{name}_O0.so"
        if o0_so.exists() and env["rusty_harness"]:
            entry, init, instance = discover_rusty_symbols(o0_so)
            if not entry:
                print(f"    SKIP: could not find entry symbol in {o0_so}")
            elif not instance:
                print(f"    SKIP: could not find instance symbol in {o0_so}")
            else:
                init_args = ["--init", init] if init else []
                for opt in ("O0", "O2"):
                    so = OUT_DIR / f"{name}_{opt}.so"
                    if not so.exists():
                        continue
                    out_json = result_dir / f"rusty_{opt}.json"
                    r = run(
                        [
                            str(RUSTY_HARNESS),
                            "--lib",
                            str(so),
                            "--entry",
                            entry,
                            "--instance",
                            instance,
                            *init_args,
                            "--cycles",
                            str(cycles),
                            "--warmup",
                            str(warmup),
                            "--opt-level",
                            opt,
                        ],
                        capture_output=True,
                        text=True,
                    )
                    if r.returncode == 0:
                        out_json.write_text(r.stdout)
                        result_files.append(out_json)
                    else:
                        print(f"    FAIL: rusty-harness -{opt}: {r.stderr.strip()}")

        # MATIEC
        if env["matiec_harness"]:
            for opt in ("O0", "O2"):
                so = OUT_DIR / f"{name}_matiec_{opt}.so"
                if not so.exists():
                    continue
                out_json = result_dir / f"matiec_{opt}.json"
                r = run(
                    [
                        str(MATIEC_HARNESS),
                        "--lib",
                        str(so),
                        "--cycles",
                        str(cycles),
                        "--warmup",
                        str(warmup),
                        "--opt-level",
                        opt,
                    ],
                    capture_output=True,
                    text=True,
                )
                if r.returncode == 0:
                    out_json.write_text(r.stdout)
                    result_files.append(out_json)
                else:
                    print(f"    FAIL: matiec-harness -{opt}: {r.stderr.strip()}")

        # IronPLC
        if env["ironplcc"]:
            plc_file = OUT_DIR / f"{name}.plc"
            if plc_file.exists():
                out_json = result_dir / "ironplc.json"
                r = run(
                    [
                        "ironplcc",
                        "bench",
                        str(plc_file),
                        "--cycles",
                        str(cycles),
                        "--warmup",
                        str(warmup),
                        "--report-format",
                        "json",
                    ],
                    capture_output=True,
                    text=True,
                )
                if r.returncode == 0:
                    out_json.write_text(r.stdout)
                    result_files.append(out_json)
                else:
                    print(f"    FAIL: ironplcc bench: {r.stderr.strip()}")

        print()

    return result_files


def validate_output_format(result_files: list[Path]) -> bool:
    """Check every JSON result has the required structure."""
    REQUIRED = {"program", "opt_level", "cycles", "warmup", "durations_us"}
    DURATION_KEYS = {"mean", "p50", "p99", "min", "max"}

    if not result_files:
        print("  ERROR: no result files to validate")
        return False

    ok = True
    for path in sorted(result_files):
        with open(path) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                print(f"  FAIL {path}: invalid JSON — {e}")
                ok = False
                continue

        missing = REQUIRED - set(data.keys())
        if missing:
            print(f"  FAIL {path}: missing keys {missing}")
            ok = False
            continue

        dur = data.get("durations_us", {})
        dur_missing = DURATION_KEYS - set(dur.keys())
        if dur_missing:
            print(f"  FAIL {path}: missing duration keys {dur_missing}")
            ok = False
            continue

        bad = False
        for k in DURATION_KEYS:
            v = dur[k]
            if not isinstance(v, (int, float)) or v < 0:
                print(f"  FAIL {path}: durations_us.{k} = {v!r}")
                ok = False
                bad = True
                break

        if not bad:
            print(
                f"  OK   {str(path):45s}  "
                f"mean={dur['mean']:8.2f}µs  "
                f"p99={dur['p99']:8.2f}µs  "
                f"max={dur['max']:8.2f}µs"
            )

    return ok


def compare_results(result_files: list[Path]) -> bool:
    """Print side-by-side comparison and check final variable state."""
    programs = sorted(set(f.parent.name for f in result_files))

    for prog in programs:
        result_dir = RESULTS_DIR / prog
        files = sorted(result_dir.glob("*.json"))
        if len(files) < 2:
            print(f"  {prog}: {len(files)} result(s) — skipping comparison")
            continue

        print(f"  {prog}:")

        entries = []
        for f in files:
            with open(f) as fh:
                data = json.load(fh)
            entries.append((f.stem, data["durations_us"]))

        print(f"    {'':20s} {'mean':>10s} {'p50':>10s} {'p99':>10s} {'max':>10s}")
        for label, dur in entries:
            print(
                f"    {label:20s} "
                f"{dur['mean']:9.2f}µs "
                f"{dur['p50']:9.2f}µs "
                f"{dur['p99']:9.2f}µs "
                f"{dur['max']:9.2f}µs"
            )

        # Overhead ratios vs RuSTy -O2
        rusty_o2 = next((dur for label, dur in entries if label == "rusty_O2"), None)
        if rusty_o2 and rusty_o2["mean"] > 0:
            for label, dur in entries:
                if label == "rusty_O2":
                    continue
                ratio = dur["mean"] / rusty_o2["mean"]
                print(f"    {label} vs rusty_O2: {ratio:.1f}x")
        print()

    # Compare final variable state
    all_pass = True
    has_vars = False
    for prog in programs:
        var_files = sorted((RESULTS_DIR / prog).glob("*_vars.json"))
        if len(var_files) < 2:
            continue

        has_vars = True
        data = {}
        for vf in var_files:
            with open(vf) as fh:
                data[vf.stem] = json.load(fh)

        names = list(data.keys())
        ref_name, ref_data = names[0], data[names[0]]
        for other_name in names[1:]:
            other_data = data[other_name]
            mismatches = [
                (var, ref_data[var], other_data.get(var))
                for var in ref_data
                if ref_data[var] != other_data.get(var)
            ]
            if mismatches:
                all_pass = False
                print(f"  FAIL  {prog}: {ref_name} vs {other_name}")
                for var, exp, act in mismatches:
                    print(f"        {var}: {exp} vs {act}")
            else:
                print(
                    f"  PASS  {prog}: {ref_name} vs {other_name} ({len(ref_data)} vars)"
                )

    if not has_vars:
        print("  (no variable capture files — final-state comparison skipped)")

    return all_pass


# ── Main ────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="End-to-end benchmark pipeline",
    )
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
        help="Program names to run (e.g. blinky arithmetic). Default: all.",
    )
    args = parser.parse_args()

    # Find ST files
    all_st = sorted(PROGRAMS_DIR.glob("*.st"))
    if args.programs:
        st_files = [f for f in all_st if f.stem in args.programs]
        if not st_files:
            print(f"No matching programs found for: {args.programs}")
            print(f"Available: {[f.stem for f in all_st]}")
            sys.exit(1)
    else:
        st_files = all_st

    if not st_files:
        print(f"No .st files found in {PROGRAMS_DIR}")
        sys.exit(1)

    print(f"Programs: {', '.join(f.stem for f in st_files)}")
    print(f"Cycles: {args.cycles}  Warmup: {args.warmup}")
    print()

    # ── 0. Build ──────────────────────────────────────────────────
    print("=" * 60)
    print("BUILD HARNESSES")
    print("=" * 60)
    build_harnesses()

    # ── 1. Discover ──────────────────────────────────────────────
    env = discover_environment()

    # ── 2. Compile ───────────────────────────────────────────────
    print("=" * 60)
    print("COMPILE")
    print("=" * 60)
    compile_programs(st_files, env)

    # ── 3. Execute ───────────────────────────────────────────────
    print("=" * 60)
    print("EXECUTE")
    print("=" * 60)
    result_files = run_benchmarks(st_files, env, args.cycles, args.warmup)

    # ── 4. Validate ──────────────────────────────────────────────
    print("=" * 60)
    print("VALIDATE OUTPUT FORMAT")
    print("=" * 60)
    format_ok = validate_output_format(result_files)

    # ── 5. Compare ───────────────────────────────────────────────
    print()
    print("=" * 60)
    print("COMPARE RESULTS")
    print("=" * 60)
    compare_ok = compare_results(result_files)

    # ── Summary ──────────────────────────────────────────────────
    print()
    print("=" * 60)
    n = len(result_files)
    if format_ok and compare_ok:
        print(f"ALL PASSED — {n} result files validated")
    else:
        if not format_ok:
            print("FAILED — output format validation errors")
        if not compare_ok:
            print("FAILED — final-state comparison mismatches")
    print("=" * 60)

    sys.exit(0 if (format_ok and compare_ok) else 1)


if __name__ == "__main__":
    main()
