FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    opam build-essential libgmp-dev z3 pkg-config zlib1g-dev \
    cmake git gcc-riscv64-unknown-elf ca-certificates device-tree-compiler \
    && rm -rf /var/lib/apt/lists/*

# Setup Opam
RUN opam init --disable-sandboxing --yes
RUN opam install sail -y

# Clone Repository
WORKDIR /workspace
RUN git clone --depth 1 https://github.com/riscv/sail-riscv.git
WORKDIR /workspace/sail-riscv

# FIX: Build and Install
# 1. We build using CMake.
# 2. We look for the generated binary in build/c_emulator.
# 3. We copy it to /usr/bin/sail_riscv_sim so it is in the PATH.
RUN eval $(opam env) && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    echo "Installing Simulator..." && \
    (cp c_emulator/sail_riscv_sim /usr/bin/sail_riscv_sim 2>/dev/null || \
     cp c_emulator/riscv_sim_RV64 /usr/bin/sail_riscv_sim) && \
    chmod +x /usr/bin/sail_riscv_sim

WORKDIR /data
CMD ["/bin/bash"]
