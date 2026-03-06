# Dockerfile for IronPLC benchmark development
#
# Provides Python 3, Rust, and LLVM 21 (required to compile RuSTy).
# Usage:
#   docker build -t ironplc-bench .
#   docker run --rm -it -v "$PWD":/workspace ironplc-bench

FROM python:3.12-bookworm

ARG LLVM_VER=21
ARG RUST_VERSION=1.90.0
ARG RUSTY_REV=ebf72fb

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# System packages: build tools + LLVM 21 dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg \
        lld \
        clang \
        lsb-release \
        pkg-config \
        software-properties-common \
        wget \
        zlib1g-dev \
        libzstd-dev \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# LLVM 21 — required by RuSTy (inkwell with llvm21-1 feature)
# ------------------------------------------------------------
RUN wget -qO- https://apt.llvm.org/llvm.sh | bash -s -- ${LLVM_VER} \
    && apt-get install -y --no-install-recommends libpolly-${LLVM_VER}-dev \
    && rm -rf /var/lib/apt/lists/*

# Make LLVM 21 tools available on PATH
ENV PATH="/usr/lib/llvm-${LLVM_VER}/bin:${PATH}"
ENV LLVM_SYS_211_PREFIX="/usr/lib/llvm-${LLVM_VER}"

# ------------------------------------------------------------
# Rust toolchain via rustup
# ------------------------------------------------------------
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal \
    && rustc --version && cargo --version

# ------------------------------------------------------------
# RuSTy IEC 61131-3 compiler (plc binary)
# Pinned to a specific commit for reproducibility.
# ------------------------------------------------------------
RUN cargo install --git https://github.com/PLC-lang/rusty --rev ${RUSTY_REV} plc_driver \
    && plc --version

# ------------------------------------------------------------
# MATIEC IEC 61131-3 compiler (iec2c binary)
# Transpiles ST to ANSI C; the generated C is then compiled
# to a shared library by GCC via matiec_compile.sh.
# ------------------------------------------------------------
ARG MATIEC_REV=2b595efea02c1a3ac1a095fb6bb4c0b34ba7046e
RUN apt-get update && apt-get install -y --no-install-recommends flex bison \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/beremiz/matiec.git /opt/matiec \
    && cd /opt/matiec \
    && git checkout ${MATIEC_REV} \
    && autoreconf -i \
    && ./configure \
    && make -j"$(nproc)" \
    && ln -s /opt/matiec/iec2c /usr/local/bin/iec2c \
    && iec2c --help 2>&1 | head -1

ENV MATIEC_C_INCLUDE_PATH=/opt/matiec/lib/C

# ------------------------------------------------------------
# Python tooling
# ------------------------------------------------------------
RUN pip install --no-cache-dir ruff

WORKDIR /workspace
