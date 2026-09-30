#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu

mkdir -p p05_mutants
echo "experiment,property,boundary,depth,result,runtime_sec,assertions,covers,mutation,counterexample,notes" > tpu_p05_control_mutation_results.csv

run_mutant() {
    mutant=$1
    prop=$2
    prop_id="P05.$prop"
    d=10
    wrapper_mutant="../../../phase_7/fault_models/nn_axi_wrapper.v"
    master_mutant="../../../phase_7/fault_models/nn_axis_master.v"
    wrapper_base="nn_axi_wrapper.v"
    master_base="nn_axis_master.v"
    
    if [ "$mutant" == "M05" ]; then
        wrapper_mutant="../../../phase_7/mutation_testing/mutants/tpu_control/M05_nn_axi_wrapper.v"
        wrapper_base="M05_nn_axi_wrapper.v"
    elif [ "$mutant" == "M06" ]; then
        master_mutant="../../../phase_7/mutation_testing/mutants/tpu_control/M06_nn_axis_master.v"
        master_base="M06_nn_axis_master.v"
    fi
    
    echo "Running Mutant $mutant on Prop $prop_id at depth $d..."
    cat <<EOF > p05_mutants/prop_${prop}_${mutant}.sby
[options]
mode bmc
depth $d

[engines]
smtbmc z3

[script]
read_verilog -formal $wrapper_base
read_verilog -formal $master_base
read_verilog -sv tpu_p05_control_wrapper.sv
read_verilog -sv tpu_p05_control_checker.sv
chparam -set PROP $prop tpu_p05_control_checker
prep -top tpu_p05_control_checker -flatten

[files]
$wrapper_mutant
$master_mutant
tpu_p05_control_wrapper.sv
tpu_p05_control_checker.sv
EOF
    
    start_time=$(date +%s)
    timeout 300 sby -f p05_mutants/prop_${prop}_${mutant}.sby -d p05_mutants/out_prop_${prop}_${mutant} > p05_mutants/log_prop_${prop}_${mutant}.log 2>&1
    exit_code=$?
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    result="ERROR"
    cx="NO"
    notes="Completed"
    
    if [ $exit_code -eq 124 ] || grep -q "terminated without status" p05_mutants/log_prop_${prop}_${mutant}.log; then
        result="TIMEOUT"
        notes="Solver exceeded budget"
    elif grep -q "DONE (PASS" p05_mutants/log_prop_${prop}_${mutant}.log; then
        result="PASS"
        notes="Mutant ESCAPED"
    elif grep -q "DONE (FAIL" p05_mutants/log_prop_${prop}_${mutant}.log; then
        result="FAIL"
        cx="YES"
        notes="Caught by property"
    else
        result="ERROR"
        notes="SBY exit code $exit_code"
    fi
    
    echo "Control_Mutation,$prop_id,tpu_p05_control_wrapper,$d,$result,$runtime,N/A,N/A,$mutant,$cx,$notes" >> tpu_p05_control_mutation_results.csv
}

# M05 removes !axis_busy check, so P05.4 should catch it.
run_mutant "M05" "4"

# M06 sets BUSY to 0 instead of 1, so P05.2 should catch it.
run_mutant "M06" "2"

echo "P05 mutation run complete."
