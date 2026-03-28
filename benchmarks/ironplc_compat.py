#!/usr/bin/env python3
"""
OSCAT compatibility test for IronPLC.

Parses all FUNCTION definitions from the OSCAT library, auto-generates
test programs, compiles with ironplcc (and optionally RuSTy), and reports
which functions compile successfully.

Usage:
    # Test all functions with IronPLC (includes full oscat.st for dependencies)
    python benchmarks/ironplc_compat.py

    # Also compile with RuSTy for comparison
    python benchmarks/ironplc_compat.py --rusty

    # Test specific functions
    python benchmarks/ironplc_compat.py --functions BINOM FIB GCD

    # Test each function in isolation (without full oscat.st)
    python benchmarks/ironplc_compat.py --no-full

    # Save JSON report
    python benchmarks/ironplc_compat.py --output report.json
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

OSCAT_ST = Path("oscat/oscat.st")

# Default test values for each IEC type
DEFAULT_VALUES: dict[str, str] = {
    "INT": "5",
    "DINT": "100",
    "UINT": "10",
    "UDINT": "1000",
    "SINT": "5",
    "USINT": "5",
    "LINT": "1000",
    "ULINT": "1000",
    "REAL": "2.5",
    "LREAL": "2.5",
    "BOOL": "TRUE",
    "BYTE": "BYTE#16#AA",
    "WORD": "WORD#16#AAAA",
    "DWORD": "DWORD#16#AABBCCDD",
    "LWORD": "LWORD#16#AABBCCDD",
    "TIME": "T#5s",
    "DATE": "D#2024-06-15",
    "DT": "DT#2024-06-15-12:30:00",
    "TOD": "TOD#12:30:00",
    "STRING": "'Hello'",
}


@dataclasses.dataclass
class FunctionDef:
    name: str
    return_type: str
    inputs: list[tuple[str, str]]  # (param_name, param_type)
    source: str  # full FUNCTION...END_FUNCTION text
    line_number: int


@dataclasses.dataclass
class TestResult:
    name: str
    skip_reason: str | None = None
    ironplc_ok: bool | None = None
    ironplc_error: str = ""
    rusty_ok: bool | None = None
    rusty_error: str = ""


# ── Parser ──────────────────────────────────────────────────────────


def parse_oscat(path: Path) -> tuple[dict[str, str], list[FunctionDef]]:
    """Parse oscat.st into TYPE blocks and FUNCTION definitions.

    Returns (types_by_name, functions) where types_by_name maps
    uppercase type name to its full TYPE...END_TYPE source text.
    """
    content = path.read_text()
    lines = content.splitlines()

    types: dict[str, str] = {}
    functions: list[FunctionDef] = []

    i = 0
    while i < len(lines):
        stripped = lines[i].strip().upper()

        # Parse TYPE blocks
        if stripped.startswith("TYPE ") and ":" in stripped:
            type_name = stripped.split()[1].rstrip(" :")
            block_lines = []
            start = i
            while i < len(lines):
                block_lines.append(lines[i])
                if lines[i].strip().upper() == "END_TYPE":
                    break
                i += 1
            types[type_name.upper()] = "\n".join(block_lines)
            i += 1
            continue

        # Parse FUNCTION blocks (skip FUNCTION_BLOCK)
        if stripped.startswith("FUNCTION ") and not stripped.startswith(
            "FUNCTION_BLOCK"
        ):
            block_lines = []
            start = i
            # Also collect preceding comment metadata lines
            while i < len(lines):
                block_lines.append(lines[i])
                if lines[i].strip().upper() == "END_FUNCTION":
                    break
                i += 1

            func = _parse_function_block("\n".join(block_lines), start + 1)
            if func:
                functions.append(func)
            i += 1
            continue

        # Skip FUNCTION_BLOCK blocks
        if stripped.startswith("FUNCTION_BLOCK "):
            while i < len(lines):
                if lines[i].strip().upper() == "END_FUNCTION_BLOCK":
                    break
                i += 1
            i += 1
            continue

        i += 1

    return types, functions


def _parse_function_block(source: str, line_number: int) -> FunctionDef | None:
    """Parse a single FUNCTION...END_FUNCTION block."""
    lines = source.splitlines()
    if not lines:
        return None

    # Parse function header: FUNCTION name : return_type
    header = lines[0].strip()
    m = re.match(r"FUNCTION\s+(\w+)\s*:\s*(.+)", header, re.IGNORECASE)
    if not m:
        return None

    name = m.group(1)
    return_type = m.group(2).strip().rstrip(";")

    # Parse VAR_INPUT
    inputs: list[tuple[str, str]] = []
    in_var_input = False
    for line in lines[1:]:
        stripped = line.strip()
        upper = stripped.upper()

        if upper.startswith("VAR_INPUT"):
            in_var_input = True
            continue
        if upper.startswith("END_VAR"):
            in_var_input = False
            continue
        if re.match(r"VAR\b|VAR_OUTPUT|VAR_IN_OUT|VAR_TEMP", upper):
            in_var_input = False
            continue

        if in_var_input:
            # Match "name : TYPE" or "name1, name2 : TYPE" or with := default
            vm = re.match(r"([\w,\s]+)\s*:\s*([^;:=]+)", stripped)
            if vm:
                var_names = [n.strip() for n in vm.group(1).split(",")]
                var_type = vm.group(2).strip()
                for vn in var_names:
                    if vn:
                        inputs.append((vn, var_type))

    return FunctionDef(
        name=name,
        return_type=return_type,
        inputs=inputs,
        source=source,
        line_number=line_number,
    )


# ── Classification ──────────────────────────────────────────────────


def _base_type(typ: str) -> str:
    """Normalize a type string for lookup: strip array bounds, STRING[N], etc."""
    t = typ.strip().upper()
    # STRING[anything] -> STRING
    if t.startswith("STRING"):
        return "STRING"
    return t


def _can_generate_value(typ: str) -> bool:
    """Check if we can generate a test value for this type."""
    base = _base_type(typ)
    if base in DEFAULT_VALUES:
        return True
    # REF_TO, ARRAY, user-defined types -> can't generate
    if "REF_TO" in typ.upper():
        return False
    if "ARRAY" in typ.upper():
        return False
    return False


def classify_function(func: FunctionDef) -> str | None:
    """Return skip reason, or None if testable."""
    for _, typ in func.inputs:
        upper = typ.upper()
        if "REF_TO" in upper:
            return "REF_TO input"
        if "ARRAY" in upper:
            return "ARRAY input"
        if not _can_generate_value(typ):
            return f"unsupported input type: {typ}"

    ret = _base_type(func.return_type)
    if ret in DEFAULT_VALUES or ret in ("STRING",):
        return None
    # User-defined return type — still try to test, just store result
    return None


def _test_value(typ: str) -> str:
    """Generate a test value literal for a type."""
    base = _base_type(typ)
    return DEFAULT_VALUES.get(base, "0")


# ── Code generation ─────────────────────────────────────────────────


def generate_test_st(
    func: FunctionDef,
    types: dict[str, str],
    full_source: str | None = None,
) -> str:
    """Generate a self-contained ST test file for a function."""
    parts: list[str] = []

    if full_source:
        # Include entire oscat.st for dependency resolution
        parts.append(full_source)
    else:
        # Include any required TYPE definitions
        ret_upper = _base_type(func.return_type)
        if ret_upper in types:
            parts.append(types[ret_upper])
            parts.append("")

        # Include the function itself
        parts.append(func.source)

    # Generate PROGRAM wrapper
    ret_type = func.return_type.strip()
    ret_base = _base_type(ret_type)
    # Use a simple variable name based on the return type
    result_var = "result"

    args = ", ".join(f"{name} := {_test_value(typ)}" for name, typ in func.inputs)
    call = f"{func.name}({args})" if args else f"{func.name}()"

    parts.append("")
    parts.append(f"PROGRAM test_{func.name}")
    parts.append("VAR")

    # For STRING return types, declare with explicit size
    if ret_base == "STRING":
        parts.append(f"    {result_var} : STRING[255];")
    else:
        parts.append(f"    {result_var} : {ret_type};")

    parts.append("END_VAR")
    parts.append(f"    {result_var} := {call};")
    parts.append("END_PROGRAM")
    parts.append("")

    return "\n".join(parts)


# ── Compilation ─────────────────────────────────────────────────────


def compile_ironplc(st_path: Path, out_dir: Path) -> tuple[bool, str]:
    """Compile with ironplcc. Returns (success, error_message)."""
    iplc = out_dir / f"{st_path.stem}.iplc"
    r = subprocess.run(
        [
            "ironplcc", "compile",
            "--dialect", "rusty",
            str(st_path), "-o", str(iplc),
        ],
        capture_output=True,
        text=True,
    )
    if r.returncode == 0:
        return True, ""
    # Strip all ANSI codes from stderr
    error = re.sub(r"\x1b\[[0-9;]*m", "", r.stderr).strip()
    # Collect all relevant error lines (error code + detail)
    error_line = ""
    detail_line = ""
    for line in error.splitlines():
        line = line.strip()
        if not line:
            continue
        if "Not implemented" in line:
            detail_line = line
        elif re.match(r"error\[P\d+\]", line):
            error_line = line
    # Prefer "Not implemented at ..." which includes the compile.rs location
    if detail_line:
        return False, detail_line
    if error_line:
        return False, error_line
    # Fallback: terminal swallowing errors or other
    for line in error.splitlines():
        line = line.strip()
        if line and "error" in line.lower():
            return False, line[:200]
    return False, error[:200] if error else "unknown error"


def find_rusty_stdlib() -> tuple[Path | None, Path | None]:
    """Locate RuSTy stdlib (reused from run_e2e.py)."""
    cargo_git = Path.home() / ".cargo" / "git" / "checkouts"
    if not cargo_git.exists():
        cargo_git = Path("/usr/local/cargo/git/checkouts")
    for checkout in sorted(cargo_git.glob("rusty-*")):
        for rev_dir in checkout.iterdir():
            st_dir = rev_dir / "libs" / "stdlib" / "iec61131-st"
            lib_a = rev_dir / "target" / "release" / "libiec61131std.a"
            if st_dir.is_dir() and list(st_dir.glob("*.st")):
                return st_dir, lib_a if lib_a.exists() else None
    return None, None


def compile_rusty(
    st_path: Path,
    out_dir: Path,
    stdlib_st: Path | None,
) -> tuple[bool, str]:
    """Compile with RuSTy. Returns (success, error_message)."""
    obj = out_dir / f"{st_path.stem}.o"
    cmd = ["plc", str(st_path)]
    if stdlib_st:
        cmd += ["-i", str(stdlib_st / "*.st")]
    cmd += ["-c", "-O", "none", "-o", str(obj)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode == 0:
        return True, ""
    error = r.stderr.strip()
    # Take first meaningful line
    for line in error.splitlines():
        line = line.strip()
        if line and not line.startswith("warning"):
            return False, line[:200]
    return False, error[:200] if error else "unknown error"


# ── Report ──────────────────────────────────────────────────────────


def print_report(results: list[TestResult], show_rusty: bool) -> None:
    """Print the compatibility report."""
    total = len(results)
    skipped = [r for r in results if r.skip_reason]
    tested = [r for r in results if not r.skip_reason]
    iron_pass = [r for r in tested if r.ironplc_ok]
    iron_fail = [r for r in tested if r.ironplc_ok is False]

    print()
    print("=" * 70)
    print("OSCAT COMPATIBILITY REPORT")
    print("=" * 70)
    print(f"  Total functions:        {total}")
    print(f"  Testable:               {len(tested)}")
    print(f"  Skipped:                {len(skipped)}")
    print(f"  IronPLC compile pass:   {len(iron_pass)}/{len(tested)}")
    print(f"  IronPLC compile fail:   {len(iron_fail)}/{len(tested)}")

    if show_rusty:
        rusty_pass = [r for r in tested if r.rusty_ok]
        rusty_fail = [r for r in tested if r.rusty_ok is False]
        print(f"  RuSTy compile pass:     {len(rusty_pass)}/{len(tested)}")
        print(f"  RuSTy compile fail:     {len(rusty_fail)}/{len(tested)}")

    # Skip reasons summary
    skip_reasons: dict[str, int] = {}
    for r in skipped:
        reason = r.skip_reason or "unknown"
        skip_reasons[reason] = skip_reasons.get(reason, 0) + 1
    if skip_reasons:
        print()
        print("  Skip reasons:")
        for reason, count in sorted(skip_reasons.items(), key=lambda x: -x[1]):
            print(f"    {reason:40s} {count}")

    # Detailed results
    print()
    if show_rusty:
        print(f"  {'Function':<25s} {'IronPLC':<10s} {'RuSTy':<10s} Notes")
        print("  " + "-" * 65)
    else:
        print(f"  {'Function':<25s} {'IronPLC':<10s} Notes")
        print("  " + "-" * 55)

    for r in results:
        if r.skip_reason:
            iron_str = "SKIP"
            rusty_str = "SKIP"
            notes = r.skip_reason
        else:
            iron_str = "PASS" if r.ironplc_ok else "FAIL"
            rusty_str = (
                "PASS" if r.rusty_ok else ("FAIL" if r.rusty_ok is False else "-")
            )
            notes = r.ironplc_error if not r.ironplc_ok else ""

        if show_rusty:
            print(f"  {r.name:<25s} {iron_str:<10s} {rusty_str:<10s} {notes}")
        else:
            print(f"  {r.name:<25s} {iron_str:<10s} {notes}")

    # Summary of IronPLC failures by error pattern
    if iron_fail:
        print()
        print("  IronPLC failure patterns:")
        patterns: dict[str, list[str]] = {}
        for r in iron_fail:
            err = r.ironplc_error
            if "Not implemented" in err:
                m = re.search(r"Not implemented at (.+)", err)
                key = f"Not implemented: {m.group(1)}" if m else "Not implemented (unknown location)"
            elif "Syntax error" in err or "P0002" in err:
                key = "Parse/syntax error (P0002)"
            elif "Unmatched character" in err or "P0003" in err:
                key = "Unmatched character (P0003)"
            elif "P0010" in err:
                key = "Edition 3 feature (P0010)"
            elif "Failed writing to terminal" in err:
                key = "Terminal error (real error hidden)"
            else:
                key = err[:80] if err else "unknown"
            patterns.setdefault(key, []).append(r.name)

        for pattern, names in sorted(patterns.items(), key=lambda x: -len(x[1])):
            count = len(names)
            examples = ", ".join(names[:5])
            if count > 5:
                examples += f", ... (+{count - 5} more)"
            print(f"    {count:3d}x  {pattern}")
            print(f"          e.g. {examples}")

    print()


def save_json_report(results: list[TestResult], path: Path) -> None:
    """Save results as JSON."""
    data = []
    for r in results:
        entry: dict = {"name": r.name}
        if r.skip_reason:
            entry["status"] = "skip"
            entry["skip_reason"] = r.skip_reason
        else:
            entry["ironplc"] = "pass" if r.ironplc_ok else "fail"
            if r.ironplc_error:
                entry["ironplc_error"] = r.ironplc_error
            if r.rusty_ok is not None:
                entry["rusty"] = "pass" if r.rusty_ok else "fail"
                if r.rusty_error:
                    entry["rusty_error"] = r.rusty_error
        data.append(entry)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


# ── Main ────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="OSCAT compatibility test for IronPLC")
    parser.add_argument(
        "--functions",
        nargs="*",
        help="Test only specific functions (by name)",
    )
    parser.add_argument(
        "--rusty",
        action="store_true",
        help="Also compile with RuSTy for comparison",
    )
    parser.add_argument(
        "--no-full",
        action="store_true",
        help="Test each function in isolation (without full oscat.st)",
    )
    parser.add_argument(
        "--output",
        metavar="PATH",
        help="Save JSON report to file",
    )
    parser.add_argument(
        "--keep",
        action="store_true",
        help="Keep generated .st files in compat_out/ for inspection",
    )
    args = parser.parse_args()

    if not OSCAT_ST.exists():
        print(f"ERROR: {OSCAT_ST} not found")
        print("Clone the OSCAT repo: git clone <oscat-repo> oscat/")
        sys.exit(1)

    if not shutil.which("ironplcc"):
        print("ERROR: ironplcc not found on PATH")
        sys.exit(1)

    rusty_stdlib_st = None
    if args.rusty:
        if not shutil.which("plc"):
            print("ERROR: plc (RuSTy) not found on PATH")
            sys.exit(1)
        rusty_stdlib_st, _ = find_rusty_stdlib()

    # Parse
    print("Parsing oscat.st...")
    types, functions = parse_oscat(OSCAT_ST)
    print(f"  Found {len(functions)} functions, {len(types)} type definitions")

    # Filter
    if args.functions:
        names = {n.upper() for n in args.functions}
        functions = [f for f in functions if f.name.upper() in names]
        if not functions:
            print("No matching functions found")
            sys.exit(1)

    # Include full oscat.st by default to resolve cross-function dependencies.
    # The compiler is expected to tree-shake unreferenced functions.
    full_source = None if args.no_full else OSCAT_ST.read_text()

    # Set up temp directory
    tmp_dir = Path("compat_out")
    tmp_dir.mkdir(exist_ok=True)

    # Test each function
    print(f"Testing {len(functions)} functions...")
    print()
    results: list[TestResult] = []

    for func in functions:
        result = TestResult(name=func.name)

        # Classify
        skip = classify_function(func)
        if skip:
            result.skip_reason = skip
            results.append(result)
            continue

        # Generate test ST file
        st_content = generate_test_st(func, types, full_source)
        st_path = tmp_dir / f"test_{func.name}.st"
        st_path.write_text(st_content)

        # Compile with IronPLC
        result.ironplc_ok, result.ironplc_error = compile_ironplc(st_path, tmp_dir)

        status = "PASS" if result.ironplc_ok else "FAIL"
        detail = f"  {result.ironplc_error}" if not result.ironplc_ok else ""
        print(f"  {func.name:<25s} {status}{detail}")

        # Compile with RuSTy
        if args.rusty:
            result.rusty_ok, result.rusty_error = compile_rusty(
                st_path, tmp_dir, rusty_stdlib_st
            )

        results.append(result)

    # Report
    print_report(results, args.rusty)

    # Save JSON
    if args.output:
        save_json_report(results, Path(args.output))
        print(f"JSON report saved: {args.output}")

    # Clean up unless --keep
    if not args.keep:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
