# Dockerfile for RV compliance testing
#
# This DOckefiles creates a consistent environement
# to test the holy core compliance to risc-v standards
# using the riscof test suite.
#
# BRH 07/25

FROM python:3.10-slim

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
      git make build-essential \
      help2man perl python3 autoconf g++ flex bison ccache \
      libgoogle-perftools-dev numactl perl-doc \
      libfl2 libfl-dev zlib1g zlib1g-dev \
      device-tree-compiler && \
    rm -rf /var/lib/apt/lists/*

# RV TOOLCHAIN 64
RUN apt-get update && apt-get install -y wget && \
    apt-get install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

# riscv32 binaries may be needed (e.g. spike) but the riscv64
# toolchain build supports these functinalities, so we create
# rv32 aliases pointing to rv64.
RUN for tool in gcc g++ cpp ar as ld objcopy objdump ranlib strip size strings elfedit nm; do \
      ln -s /bin/riscv64-unknown-elf-$tool /bin/riscv32-unknown-elf-$tool || true; \
    done

# hexdump
RUN apt-get update && apt-get install -y bsdmainutils

# Build & install Verilator
RUN git clone https://github.com/verilator/verilator && \
cd verilator && \
git checkout stable && \
autoconf && \
./configure && \
make -j$(nproc) && \
make install

# Build and install RV reference (spike)
RUN git clone https://github.com/riscv-software-src/riscv-isa-sim.git && \
cd riscv-isa-sim && \
mkdir build && cd build && \
../configure --prefix=/bin && \
make && \
make install
ENV PATH="/riscv-isa-sim/build:${PATH}"

WORKDIR /compliance_test

# Copy source and "cd" into riscof dedicated folder
COPY . .

# Install riscof, cocotb etc...
RUN pip install riscof && \
pip install -r requirements.txt

WORKDIR /compliance_test/riscof

# uncomment to clone tests during build
# if not done on host machine before
RUN riscof --verbose info arch-test --clone
