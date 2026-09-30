#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu/depth_sweep

echo "depth,result,runtime_seconds,solver,timeout_seconds,assertions,covers,counterexample,exit_status,notes" > tpu_formal_depth_sweep.csv

for d in 1 2 4 6 8 10; do
    echo "Running depth $d..."
    cat <<EOF > tpu_interface_$d.sby
[options]
mode bmc
depth $d

[engines]
smtbmc z3

[script]
read_verilog -formal nn_axi_wrapper.v
read_verilog -formal nn_axis_master.v
read_verilog -sv tpu_interface_formal.sv
prep -top tpu_interface_formal

[files]
../../../../phase_7/fault_models/nn_axi_wrapper.v
../../../../phase_7/fault_models/nn_axis_master.v
../tpu_interface_formal.sv
EOF

    start_time=$(date +%s)
    timeout 300 sby -f tpu_interface_$d.sby -d depth_$d > depth_$d.log 2>&1
    exit_code=$?
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    result="ERROR"
    cx="NO"
    notes="Completed"
    
    if [ $exit_code -eq 124 ]; then
        result="TIMEOUT"
        notes="Solver exceeded 300s budget"
    elif grep -q "DONE (PASS" depth_$d.log; then
        result="PASS"
        notes="Completed successfully"
    elif grep -q "DONE (FAIL" depth_$d.log; then
        result="FAIL"
        cx="YES"
        notes="Counterexample found"
    elif grep -q "Engine terminated without status" depth_$d.log || grep -q "Unexpected EOF" depth_$d.log; then
        result="ERROR"
        notes="Z3 solver crashed or hung and was terminated"
    else
        result="ERROR"
        notes="SBY exit code $exit_code"
    fi
    
    echo "$d,$result,$runtime,Z3,300,1,3,$cx,$exit_code,$notes" >> tpu_formal_depth_sweep.csv
done
