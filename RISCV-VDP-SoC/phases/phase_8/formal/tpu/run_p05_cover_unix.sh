#!/bin/bash
set -e
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu

mkdir -p p05_cover_results
echo "experiment,property,target,depth,result,runtime_sec,trace_step,traces,notes" > tpu_p05_cover_results.csv

for d in 1 2 4 6 8 10; do
    echo "Running TPU Cover Reachability at depth $d..."
    cat << 'SBYEOF' > p05_cover_results/cover_depth_${d}.sby
[options]
mode cover
depth DEPTH_VAL

[engines]
smtbmc z3

[script]
read_verilog -formal nn_axi_wrapper.v
read_verilog -formal nn_axis_master.v
read_verilog -sv tpu_p05_control_wrapper.sv
read_verilog -sv tpu_p05_control_checker.sv
prep -top tpu_p05_control_checker -flatten

[files]
../../../phase_7/fault_models/nn_axi_wrapper.v
../../../phase_7/fault_models/nn_axis_master.v
tpu_p05_control_wrapper.sv
tpu_p05_control_checker.sv
SBYEOF

    sed -i "s/DEPTH_VAL/$d/g" p05_cover_results/cover_depth_${d}.sby

    start_time=$(date +%s)
    timeout 120 sby -f p05_cover_results/cover_depth_${d}.sby -d p05_cover_results/out_cover_depth_${d} > p05_cover_results/log_cover_depth_${d}.log 2>&1 || true
    end_time=$(date +%s)
    runtime=$((end_time - start_time))

    log_file="p05_cover_results/log_cover_depth_${d}.log"
    if grep -q "DONE (PASS" "$log_file"; then
        result="PASS"
        traces=$(grep -c "Reached cover statement" "$log_file" || true)
        steps=$(grep -o "in step [0-9]*" "$log_file" | awk '{print $3}' | tr '\n' ',' | sed 's/,$//')
        notes="Covered $traces target(s) at step(s) $steps"
    elif grep -q "DONE (FAIL" "$log_file"; then
        result="UNREACHABLE"
        traces="0"
        steps="none"
        notes="Cover condition unreachable within depth $d"
    else
        result="ERROR"
        traces="0"
        steps="none"
        notes="Execution failed or timed out"
    fi

    echo "TPU_Control_Cover,COVER_axis_start_m_axis_tvalid,tpu_p05_control_checker,$d,$result,$runtime,$steps,$traces,$notes" >> tpu_p05_cover_results.csv
done

echo "TPU Cover runs complete."
