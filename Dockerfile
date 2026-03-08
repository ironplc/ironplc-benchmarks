# Dockerfile for IronPLC benchmark development
#
# Sets up the build environment (Rust, LLVM 21, Python, flex/bison).
# Compilers (RuSTy, MATIEC, IronPLC) are installed separately via setup.sh.
#
# Usage:
#   docker build -t ironplc-bench .
#   docker run --rm -it -v "$PWD":/workspace ironplc-bench
#   ./setup.sh          # install compilers (first time only)

FROM python:3.12-bookworm

ARG LLVM_VER=21
ARG RUST_VERSION=1.90.0

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
        flex \
        bison \
        autoconf \
        automake \
        libtool \
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
# Python tooling
# ------------------------------------------------------------
RUN pip install --no-cache-dir ruff

WORKDIR /workspace
