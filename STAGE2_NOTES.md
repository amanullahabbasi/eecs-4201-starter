# Stage 2 Control Pipeline Contribution

Aman owned the control-pipeline portion of Stage 2. This branch adds a reusable control propagation block for the 5-stage pipeline and a focused testbench for its stall, hold, and bubble behavior.

Files:

- `code/control_pipeline.sv`
- `verif/control_pipeline_tb.sv`

The block carries decode control through ID/EX, EX/MEM, and MEM/WB. Clear signals turn control into a bubble so stalls and flushes do not write registers or memory.

Verification:

```text
make -C verif tb-control_pipeline_tb VERILATOR="/opt/homebrew/bin/verilator -Wno-fatal"
```
