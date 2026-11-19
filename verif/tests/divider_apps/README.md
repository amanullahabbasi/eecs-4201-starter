# Divider application tests

These three small RV32IM programs check the divider in a working processor,
including branches, data dependencies, stalls, and register writeback.

- `prime-check`: trial division identifies 29 as prime and 35 as composite,
  finding its factor 5. It repeatedly uses `REMU` in two loops.
- `scale-average`: calculates 73 / 5 as quotient 14, remainder 3, and rounded
  average 15; it also checks signed fixed-point scaling -1234 / 10 as quotient
  -123, remainder -4.
- `gcd-euclid`: Euclid's algorithm computes gcd(48, 18) = 6 and
  gcd(1071, 462) = 21. Each remainder feeds the next iteration.

Each program sets x1 to 1 only after every expected result is checked. The
existing `top_tb` reports a pass if x1 is 1 when `ecall` completes.

Regenerate the `.x` images after editing the readable `.txt` programs:

```sh
python3 verif/tests/divider_apps/assemble.py
```

Run all three from the repository root (requires Verilator):

```sh
make sim TEST_DIR=divider_apps -C verif
```

For an individual test, add `TEST=prime-check`, `TEST=scale-average`, or
`TEST=gcd-euclid` to the command.
