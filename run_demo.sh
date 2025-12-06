#!/bin/bash
set -euo pipefail

IMAGE_NAME="riscv-sail-env-2404"

echo "=== 1. Generating Source Files ==="

# 1. Create Dockerfile
cat <<EOF > Dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \\
    opam build-essential libgmp-dev z3 pkg-config zlib1g-dev \\
    cmake git gcc-riscv64-unknown-elf ca-certificates device-tree-compiler \\
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
RUN eval \$(opam env) && \\
    mkdir build && \\
    cd build && \\
    cmake -DCMAKE_BUILD_TYPE=Release .. && \\
    make -j\$(nproc) && \\
    echo "Installing Simulator..." && \\
    (cp c_emulator/sail_riscv_sim /usr/bin/sail_riscv_sim 2>/dev/null || \\
     cp c_emulator/riscv_sim_RV64 /usr/bin/sail_riscv_sim) && \\
    chmod +x /usr/bin/sail_riscv_sim

WORKDIR /data
CMD ["/bin/bash"]
EOF

# 2. Create Linker Script (link.ld)
cat <<EOF > link.ld
OUTPUT_ARCH( "riscv" )
ENTRY( _start )
PHDRS {
  text PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS {
  . = 0x80000000;
  .text : { *(.text.init) *(.text) } :text
  . = ALIGN(0x1000);
  .data : { *(.tohost) *(.data) } :data
  .bss : { *(.bss) } :data
  . = . + 0x1000;
  _stack_top = .;
}
EOF

# 3. Create Startup Code (head.S)
cat <<EOF > head.S
.section .text.init
.global _start
_start:
    la sp, _stack_top
    call main
    
    # Exit Sequence
    slli t0, a0, 1
    ori  t0, t0, 1
    la t1, tohost
    sd t0, 0(t1)
1:  j 1b

.section .tohost
.align 6
.global tohost
tohost: .dword 0
.global fromhost
fromhost: .dword 0
EOF

# 4. Create Main Logic (main.c)
cat <<EOF > main.c
typedef unsigned long long uint64_t;
typedef unsigned char      uint8_t;

extern volatile uint64_t tohost;

void htif_console_putchar(char c) {
    uint64_t payload = 0x0101000000000000 | (uint8_t)c;
    while (tohost != 0);
    tohost = payload;
}

void print_str(const char *s) { 
    while (*s) htif_console_putchar(*s++); 
}

void print_int(int n) {
    if (n == 0) { htif_console_putchar('0'); return; }
    char buf[32]; 
    int i = 0;
    while (n > 0) { buf[i++] = (n % 10) + '0'; n /= 10; }
    while (--i >= 0) htif_console_putchar(buf[i]);
}

int main() {
    print_str("Calculation Result: ");
    print_int(10 + 20);
    print_str("\n");
    return 0;
}
EOF

echo "=== 2. Building Docker Image (Ubuntu 24.04) ==="
docker build -t ${IMAGE_NAME} .

echo "=== 3. Compiling and Running in Container ==="
docker run --rm -v "$(pwd):/data" ${IMAGE_NAME} bash -c "
    set -e
    echo '[Container] Compiling bootable.elf...'
    
    # Compile ELF
    riscv64-unknown-elf-gcc \
        -march=rv64g -mabi=lp64 \
        -static -mcmodel=medany \
        -fvisibility=hidden -nostdlib -nostartfiles -ffreestanding \
        -Wl,--no-warn-rwx-segments \
        -T link.ld head.S main.c -o bootable.elf
    
    echo '[Container] Running SAIL Simulator...'
    echo '--------------------------------------'
    # This command now maps to the correct binary inside the container
    sail_riscv_sim bootable.elf
    echo '--------------------------------------'
"
