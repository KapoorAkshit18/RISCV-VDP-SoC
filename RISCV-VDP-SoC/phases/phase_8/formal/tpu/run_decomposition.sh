#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu

mkdir -p decomposition
echo "property_id,target,depth,result,runtime_seconds,solver,counterexample,notes" > tpu_formal_decomposition.csv

run_test() {
    prop=$1
    target=$2
    checker=$3
    d=$4
    
    echo "Running Prop P0$prop (Target: $target) at depth $d..."
    cat <<EOF > decomposition/prop_${prop}_depth_${d}.sby
[options]
mode bmc
depth $d

[engines]
smtbmc z3

[script]
read_verilog -formal ../../../phase_7/fault_models/nn_axis_master.v
read_verilog -formal ../../../phase_7/fault_models/nn_axi_wrapper.v
read_verilog -sv $checker
chparam -set PROP $prop $target
prep -top $target -flatten

[files]
../../../phase_7/fault_models/nn_axis_master.v
../../../phase_7/fault_models/nn_axi_wrapper.v
$checker
EOF
    
    start_time=$(date +%s)
    timeout 100 sby -f decomposition/prop_${prop}_depth_${d}.sby -d decomposition/out_prop_${prop}_depth_${d} > decomposition/log_prop_${prop}_depth_${d}.log 2>&1
    exit_code=$?
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    result="ERROR"
    cx="NO"
    notes="Completed"
    
    if [ $exit_code -eq 124 ] || grep -q "terminated without status" decomposition/log_prop_${prop}_depth_${d}.log; then
        result="TIMEOUT"
        notes="Solver exceeded budget"
    elif grep -q "DONE (PASS" decomposition/log_prop_${prop}_depth_${d}.log; then
        result="PASS"
        notes="Completed successfully"
    elif grep -q "DONE (FAIL" decomposition/log_prop_${prop}_depth_${d}.log; then
        result="FAIL"
        cx="YES"
        notes="Counterexample found"
    else
        result="ERROR"
        notes="SBY exit code $exit_code"
    fi
    
    echo "TPU_P0$prop,$target,$d,$result,$runtime,z3,$cx,$notes" >> tpu_formal_decomposition.csv
}

# Run tractable AXI properties
for prop in 1 2 3 4 6; do
    for d in 1 2 4 6 8 10; do
        run_test $prop "tpu_axis_checker" "tpu_axis_checker.sv" $d
    done
done

# Run intractable MMIO property
for prop in 5; do
    # Only run depth 1,2 to demonstrate timeout quickly
    for d in 1 2; do
        run_test $prop "tpu_mmio_checker" "tpu_mmio_checker.sv" $d
    done
done

echo "Golden run complete."
