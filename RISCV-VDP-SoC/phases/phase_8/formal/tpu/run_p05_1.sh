#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu
prop=1
for d in 1 2 4 6 8 10; do
    echo "Running Prop P05.1 at depth $d..."
    sby -f p05_results/prop_1_depth_$d.sby -d p05_results/out_prop_1_depth_${d}_new > p05_results/log_prop_1_depth_$d.log 2>&1
    grep -E 'DONE \(PASS|DONE \(FAIL' p05_results/log_prop_1_depth_$d.log
done
