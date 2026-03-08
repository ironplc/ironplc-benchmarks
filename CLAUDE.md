# CLAUDE.md — Project conventions for Claude Code

## Setup

Install all compilers (RuSTy, MATIEC, IronPLC) and build harnesses:

```bash
python setup.py
```

This is idempotent — it skips anything already installed. Use `--force` to reinstall.

## Running benchmarks

```bash
# Full run (all programs, 1000 cycles)
python benchmarks/run_e2e.py

# Quick smoke test
python benchmarks/run_e2e.py --cycles 100 --warmup 10

# Single program
python benchmarks/run_e2e.py --programs blinky
```

## Pre-commit checks

Before committing any changes, always run these checks and fix any issues:

```bash
# Python formatting and linting
ruff format --check .
ruff check .

# Rust linting (if Rust files were changed)
cd benchmarks/rusty_harness && cargo clippy -- -D warnings && cd ../..
cd benchmarks/matiec_harness && cargo clippy -- -D warnings && cd ../..

# Shell scripts (if any .sh files were changed)
shellcheck **/*.sh
```

## Code style

- Python: formatted by `ruff format` (line length 88, default ruff rules)
- Rust: standard `cargo fmt` + `cargo clippy`
- Shell: checked by `shellcheck`

## Project structure

- `setup.py` — Installs compilers (RuSTy, MATIEC, IronPLC) and builds harnesses
- `benchmarks/programs/` — IEC 61131-3 Structured Text benchmark programs
- `benchmarks/rusty_harness/` — Rust binary that loads RuSTy-compiled .so files
- `benchmarks/matiec_harness/` — Rust binary that loads MATIEC-compiled .so files
- `benchmarks/run_e2e.py` — End-to-end benchmark pipeline
- `.github/workflows/benchmark.yml` — CI: full E2E benchmark pipeline
- `.github/workflows/ci.yml` — CI: Docker build, harness build, lint
