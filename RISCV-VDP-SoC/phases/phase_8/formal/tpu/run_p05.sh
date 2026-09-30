#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu

mkdir -p p05_results
echo "experiment,property,boundary,depth,result,runtime_sec,assertions,covers,mutation,counterexample,notes" > tpu_p05_control_formal_results.csv

run_test() {
    prop=$1
    prop_id="P05.$prop"
    d=$2
    
    echo "Running Prop $prop_id at depth $d..."
    cat <<EOF > p05_results/prop_${prop}_depth_${d}.sby
[options]
mode bmc
depth $d

[engines]
smtbmc z3

[script]
read_verilog -formal nn_axi_wrapper.v
read_verilog -formal nn_axis_master.v
read_verilog -sv tpu_p05_control_wrapper.sv
read_verilog -sv tpu_p05_control_checker.sv
chparam -set PROP $prop tpu_p05_control_checker
prep -top tpu_p05_control_checker -flatten

[files]
../../../phase_7/fault_models/nn_axi_wrapper.v
../../../phase_7/fault_models/nn_axis_master.v
tpu_p05_control_wrapper.sv
tpu_p05_control_checker.sv
EOF
    
    start_time=$(date +%s)
    timeout 300 sby -f p05_results/prop_${prop}_depth_${d}.sby -d p05_results/out_prop_${prop}_depth_${d} > p05_results/log_prop_${prop}_depth_${d}.log 2>&1
    exit_code=$?
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    result="ERROR"
    cx="NO"
    notes="Completed"
    
    if [ $exit_code -eq 124 ] || grep -q "terminated without status" p05_results/log_prop_${prop}_depth_${d}.log; then
        result="TIMEOUT"
        notes="Solver exceeded budget"
    elif grep -q "DONE (PASS" p05_results/log_prop_${prop}_depth_${d}.log; then
        result="PASS"
        notes="Completed successfully"
    elif grep -q "DONE (FAIL" p05_results/log_prop_${prop}_depth_${d}.log; then
        result="FAIL"
        cx="YES"
        notes="Counterexample found"
    else
        result="ERROR"
        notes="SBY exit code $exit_code"
    fi
    
    echo "Control_Boundary,$prop_id,tpu_p05_control_wrapper,$d,$result,$runtime,N/A,N/A,NO,$cx,$notes" >> tpu_p05_control_formal_results.csv
}

for prop in 1 2 3 4 5; do
    for d in 1 2 4 6 8 10; do
        run_test $prop $d
    done
done

echo "P05 run complete."
