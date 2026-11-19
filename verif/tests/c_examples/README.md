# Running C programs on the RV32IM core

From the repository root:

```sh
python3 verif/run_c.py verif/tests/c_examples/division.c
python3 verif/run_c.py /path/to/professors_program.c --expected 1
```

The C file must define `int main(void)`. By default, a return value of `1`
means success; use `--expected N` if the program should return a different
integer. The script compiles for RV32IM, creates a `.x` memory image, runs
the existing Verilator testbench, and checks for `Test Passed`. It prints the
image and disassembly paths under `verif/tests/generated_c/` for inspection.

This is a **freestanding** C environment: there is no `printf`, standard C
library, operating system, or dynamic allocation. Programs may use plain C
arithmetic, arrays, functions, loops, branches, and static data. The simulator
has a 10,000-cycle timeout and 1 MiB memory. Install `riscv64-elf-gcc` (or
`riscv64-unknown-elf-gcc`), its `objcopy` and `objdump`, `make`, and Verilator.
Use `--build-only` to compile without running the simulator.
