# Stage 2 Verification Summary

Team: VanguardV

This submission implements a five-stage in-order RV32I core with pipeline registers, hazard detection, data forwarding, branch/control handling, and synthesis support. The core was checked with the official benchmark suite, focused Stage 2 pipeline testbenches, and the synthesis/timing flow provided for the course.

## Functional verification

The design was verified with the provided instruction and sample benchmark tests. The focused Stage 2 testbenches cover control-signal propagation through the pipeline, pipeline clear/hold behavior, load-use hazard stalling, forwarding priority, zero-register forwarding suppression, and flush behavior.

## Synthesis verification

Synthesis was run on the EECS remote server from a `librelane` shell using the course Yosys/OpenSTA flow. The synthesis script uses the SystemVerilog frontend expected by the course toolchain and includes the timing analysis script. The design synthesizes successfully and produces `synth.v`, `synth.json`, an area report, and timing statistics.

The final timing report records the synthesized chip area, sequential-element area, minimum clock period, estimated maximum frequency, and the reported maximum-delay critical path. The critical path is reported between synthesized internal flip-flop cell names after technology mapping, so the exact RTL signal names are not directly preserved in the summary output.

## Revision and review evidence

The project was maintained in Git with separate commits for the Stage 2 datapath, hazard/forwarding/stall logic, synthesis preparation, main-memory synthesis cleanup, and final synthesis-script compatibility updates. The GitHub Actions workflow runs smoke tests and the focused Stage 2 testbenches on future pushes and pull requests.
