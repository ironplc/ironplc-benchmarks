#!/usr/bin/env python3
"""
Install compilers and build harnesses for the benchmark suite.

Run this once after starting the dev container. Re-running is safe —
each step skips if already installed. Use --force to reinstall.

Usage:
    python setup.py              # install everything
    python setup.py --force      # reinstall even if present
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path

# Pinned versions — override via environment variables
RUSTY_REV = os.environ.get("RUSTY_REV", "ebf72fb")
MATIEC_REV = os.environ.get(
    "MATIEC_REV", "2b595efea02c1a3ac1a095fb6bb4c0b34ba7046e"
)
IRONPLC_REV = os.environ.get("IRONPLC_REV", "main")

SCRIPT_DIR = Path(__file__).resolve().parent


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=True, **kwargs)


def has_tool(name: str) -> bool:
    return shutil.which(name) is not None


def install_rusty(force: bool) -> None:
    print("[rusty]")
    if has_tool("plc") and not force:
        print("  already installed — skipping (use --force to reinstall)")
        return
    run(
        [
            "cargo", "install",
            "--git", "https://github.com/PLC-lang/rusty",
            "--rev", RUSTY_REV,
            "plc_driver",
        ]
    )


def install_matiec(force: bool) -> None:
    print("[matiec]")
    if has_tool("iec2c") and not force:
        print("  already installed — skipping (use --force to reinstall)")
        return

    matiec_dir = Path("/opt/matiec")
    if matiec_dir.exists():
        run(["git", "-C", str(matiec_dir), "fetch"])
        run(["git", "-C", str(matiec_dir), "checkout", MATIEC_REV])
    else:
        run(["git", "clone", "https://github.com/beremiz/matiec.git", str(matiec_dir)])
        run(["git", "-C", str(matiec_dir), "checkout", MATIEC_REV])

    run(["autoreconf", "-i"], cwd=matiec_dir)
    run(["./configure"], cwd=matiec_dir)
    run(["make", f"-j{os.cpu_count() or 1}"], cwd=matiec_dir)

    iec2c_link = Path("/usr/local/bin/iec2c")
    iec2c_link.unlink(missing_ok=True)
    iec2c_link.symlink_to(matiec_dir / "iec2c")

    os.environ.setdefault("MATIEC_C_INCLUDE_PATH", str(matiec_dir / "lib" / "C"))


def install_ironplc(force: bool) -> None:
    print("[ironplc]")
    if has_tool("ironplcc") and has_tool("ironplcvm") and not force:
        print("  already installed — skipping (use --force to reinstall)")
        return

    run(
        [
            "cargo", "install",
            "--git", "https://github.com/ironplc/ironplc",
            "--branch", IRONPLC_REV,
            "ironplcc",
        ]
    )
    run(
        [
            "cargo", "install",
            "--git", "https://github.com/ironplc/ironplc",
            "--branch", IRONPLC_REV,
            "ironplc-vm-cli",
        ]
    )


def build_harnesses() -> None:
    print("[harnesses]")
    for name, crate_dir in [
        ("rusty-harness", SCRIPT_DIR / "benchmarks" / "rusty_harness"),
        ("matiec-harness", SCRIPT_DIR / "benchmarks" / "matiec_harness"),
    ]:
        cargo_toml = crate_dir / "Cargo.toml"
        if not cargo_toml.exists():
            print(f"  {name}: no Cargo.toml — skipping")
            continue
        print(f"  building {name}...")
        run(["cargo", "build", "--release", "--manifest-path", str(cargo_toml)])


def main() -> None:
    parser = argparse.ArgumentParser(description="Install benchmark compilers and harnesses")
    parser.add_argument("--force", action="store_true", help="Reinstall even if present")
    args = parser.parse_args()

    print("=" * 60)
    print("SETUP — Install compilers and build harnesses")
    print("=" * 60)
    print(f"  RUSTY_REV:   {RUSTY_REV}")
    print(f"  MATIEC_REV:  {MATIEC_REV}")
    print(f"  IRONPLC_REV: {IRONPLC_REV}")
    print()

    install_rusty(args.force)
    print()
    install_matiec(args.force)
    print()
    install_ironplc(args.force)
    print()
    build_harnesses()

    print()
    print("=" * 60)
    print("SETUP COMPLETE")
    print("=" * 60)
    print()
    for name in ("plc", "iec2c", "ironplcc", "ironplcvm"):
        path = shutil.which(name) or "NOT FOUND"
        print(f"  {name:12s} {path}")
    print()
    print("Next: python benchmarks/run_e2e.py --cycles 100 --warmup 10")


if __name__ == "__main__":
    main()
