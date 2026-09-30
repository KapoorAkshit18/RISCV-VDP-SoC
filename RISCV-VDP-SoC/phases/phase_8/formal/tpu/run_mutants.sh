#!/bin/bash
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/tpu

mkdir -p mutant_results
echo "mutant,property_id,golden_result,mutant_result,counterexample_detected,notes" > tpu_mutation_formal_results.csv

run_mutant() {
    mutant=$1
    prop=$2
    golden="PASS"
    
    echo "Running Mutant $mutant on Prop P0$prop..."
    cat <<EOF > mutant_results/${mutant}_prop_${prop}.sby
[options]
mode bmc
depth 10

[engines]
smtbmc z3

[script]
read_verilog -formal ${mutant}_nn_axis_master.v
read_verilog -sv tpu_axis_checker.sv
chparam -set PROP $prop tpu_axis_checker
prep -top tpu_axis_checker -flatten

[files]
mutants/${mutant}_nn_axis_master.v
tpu_axis_checker.sv
EOF
    
    timeout 100 sby -f mutant_results/${mutant}_prop_${prop}.sby -d mutant_results/out_${mutant}_prop_${prop} > mutant_results/log_${mutant}_prop_${prop}.log 2>&1
    exit_code=$?
    
    mutant_result="ERROR"
    cx="NO"
    notes="Completed"
    
    if [ $exit_code -eq 124 ] || grep -q "terminated without status" mutant_results/log_${mutant}_prop_${prop}.log; then
        mutant_result="TIMEOUT"
    elif grep -q "DONE (PASS" mutant_results/log_${mutant}_prop_${prop}.log; then
        mutant_result="PASS"
        notes="Escaped! Mutant not caught by property"
    elif grep -q "DONE (FAIL" mutant_results/log_${mutant}_prop_${prop}.log; then
        mutant_result="FAIL"
        cx="YES"
        notes="Caught by property"
    else
        mutant_result="ERROR"
    fi
    
    echo "$mutant,TPU_P0$prop,$golden,$mutant_result,$cx,$notes" >> tpu_mutation_formal_results.csv
}

# M01 -> Payload stability (Prop 2)
run_mutant "M01" 2
# M02 -> TLAST (Prop 4)
run_mutant "M02" 4
# M03 -> Transfer qualification (Prop 3)
run_mutant "M03" 3

echo "Mutation runs complete."
