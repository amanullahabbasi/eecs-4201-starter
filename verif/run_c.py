#!/usr/bin/env python3
"""Compile a freestanding RV32IM C program and run it on the Verilator core."""

import argparse
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path


VERIF = Path(__file__).resolve().parent
OUTPUT = VERIF / "tests" / "generated_c"
BASE_ADDR = 0x01000000
MAX_BYTES = 1024 * 1024


def tool(name, candidates):
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    raise RuntimeError(f"Missing {name}. Install a RISC-V bare-metal GCC toolchain and add it to PATH.")


def run(command, **kwargs):
    print("+", " ".join(map(str, command)), flush=True)
    return subprocess.run(command, **{"check": True, **kwargs})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="C file containing int main(void)")
    parser.add_argument("--expected", type=lambda s: int(s, 0), default=1,
                        help="expected return value from main (default: 1)")
    parser.add_argument("--opt", choices=["0", "1", "2"], default="0",
                        help="GCC optimization level (default: 0)")
    parser.add_argument("--build-only", action="store_true",
                        help="compile and make the .x image without running Verilator")
    args = parser.parse_args()

    source = args.source.resolve()
    if not source.is_file() or source.suffix != ".c":
        parser.error("source must be an existing .c file")
    if not -(2**31) <= args.expected < 2**32:
        parser.error("--expected must fit in 32 bits")

    gcc = tool("RISC-V GCC", ["riscv64-elf-gcc", "riscv64-unknown-elf-gcc",
                                    "riscv32-unknown-elf-gcc"])
    prefix = Path(gcc).name.removesuffix("gcc")
    objcopy = tool("RISC-V objcopy", [prefix + "objcopy"])
    objdump = tool("RISC-V objdump", [prefix + "objdump"])
    make = tool("make", ["make"])

    name = re.sub(r"[^A-Za-z0-9_-]", "_", source.stem)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    startup = OUTPUT / f"{name}_start.S"
    linker = OUTPUT / f"{name}.ld"
    elf = OUTPUT / f"{name}.elf"
    binary = OUTPUT / f"{name}.bin"
    image = OUTPUT / f"{name}.x"
    disassembly = OUTPUT / f"{name}.objdump"

    # Keep sp below its reset value so top_tb's separate RET-completion detector
    # does not race our ECALL check. x1=1 is top_tb's success convention.
    startup.write_text(f""".section .text.start,\"ax\"
.globl _start
_start:
    addi sp, sp, -16
    call main
    li t0, {args.expected & 0xffffffff}
    bne a0, t0, failed
    li ra, 1
    j finished
failed:
    li ra, 0
finished:
    ecall
halt:
    j halt
""")
    linker.write_text(f"""ENTRY(_start)
SECTIONS {{
  . = 0x{BASE_ADDR:08x};
  .text : {{ *(.text.start) *(.text .text.*) }}
  .rodata : {{ *(.rodata .rodata.*) }}
  . = ALIGN(4);
  .data : {{ *(.data .data.*) *(.sdata .sdata.*) }}
  . = ALIGN(4);
  .bss : {{ *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) }}
}}
""")

    run([gcc, "-march=rv32im", "-mabi=ilp32", "-mcmodel=medany", "-mno-relax",
         f"-O{args.opt}", "-ffreestanding", "-fno-builtin", "-fno-stack-protector",
         "-nostdlib", "-nostartfiles", "-Wl,--no-relax", f"-Wl,-T,{linker}",
         str(startup), str(source), "-o", str(elf)])
    run([objcopy, "-O", "binary", str(elf), str(binary)])
    with disassembly.open("w") as stream:
        run([objdump, "-d", str(elf)], stdout=stream)
    data = binary.read_bytes()
    if not data or len(data) > MAX_BYTES:
        raise RuntimeError(f"Program image must be 1 to {MAX_BYTES} bytes, got {len(data)}")
    data += bytes((-len(data)) % 4)
    image.write_text("".join(f"{word:08x}\n" for (word,) in struct.iter_unpack("<I", data)))
    print(f"Image: {image}\nDisassembly: {disassembly}", flush=True)

    if args.build_only:
        return 0
    result = run([make, "-C", str(VERIF), "sim", "TEST_DIR=generated_c",
                  f"TEST={name}"], cwd=VERIF, text=True, stdout=subprocess.PIPE,
                 stderr=subprocess.STDOUT, check=False)
    print(result.stdout, end="")
    if result.returncode != 0 or "Test Passed" not in result.stdout:
        print("C program FAILED (or simulator did not complete).", file=sys.stderr)
        return 1
    print(f"C program PASSED: main() returned {args.expected}.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
