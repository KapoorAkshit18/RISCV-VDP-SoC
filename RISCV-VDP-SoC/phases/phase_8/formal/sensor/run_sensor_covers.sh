#!/bin/bash
set -e
cd /mnt/c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_8/formal/sensor

mkdir -p sensor_cover_results
echo "property_id,description,target,depth,result,runtime_sec,trace_step,traces,notes" > sensor_formal_cover_results.csv

run_cover() {
    cid=$1
    pid=$2
    desc=$3
    depth=6

    echo "Running Sensor Cover $pid ($desc) at depth $depth..."
    cat << 'SBYEOF' > sensor_cover_results/cover_${cid}.sby
[options]
mode cover
depth DEPTH_VAL

[engines]
smtbmc z3

[script]
read_verilog -formal sensor_status_native.v
read_verilog -sv sensor_cover_top.sv
chparam -set COVER_ID CID_VAL sensor_formal_cover_top
prep -top sensor_formal_cover_top -flatten

[files]
../../../phase_7/fault_models/sensor_status_native.v
sensor_cover_top.sv
SBYEOF

    sed -i "s/DEPTH_VAL/$depth/g" sensor_cover_results/cover_${cid}.sby
    sed -i "s/CID_VAL/$cid/g" sensor_cover_results/cover_${cid}.sby

    start_time=$(date +%s)
    timeout 60 sby -f sensor_cover_results/cover_${cid}.sby -d sensor_cover_results/out_cover_${cid} > sensor_cover_results/log_cover_${cid}.log 2>&1 || true
    end_time=$(date +%s)
    runtime=$((end_time - start_time))

    log_file="sensor_cover_results/log_cover_${cid}.log"
    if grep -q "DONE (PASS" "$log_file"; then
        result="PASS"
        traces=$(grep -c "Reached cover statement" "$log_file" || true)
        step=$(grep "Reached cover statement" "$log_file" | grep -o "in step [0-9]*" | awk '{print $3}' | head -n 1)
        notes="Covered at step $step"
    elif grep -q "DONE (FAIL" "$log_file"; then
        result="UNREACHABLE"
        traces="0"
        step="none"
        notes="Cover condition unreachable within depth $depth"
    else
        result="ERROR"
        traces="0"
        step="none"
        notes="Execution failed"
    fi

    echo "$pid,$desc,sensor_status_native_slave,$depth,$result,$runtime,$step,$traces,$notes" >> sensor_formal_cover_results.csv
}

run_cover 1 "SEN_C01" "Battery low threshold - 1 (14%)"
run_cover 2 "SEN_C02" "Battery low threshold (15%)"
run_cover 3 "SEN_C03" "Battery low threshold + 1 (16%)"
run_cover 4 "SEN_C04" "Temperature alarm - 0.1C (79.9C)"
run_cover 5 "SEN_C05" "Temperature alarm threshold (80.0C)"
run_cover 6 "SEN_C06" "Temperature alarm + 0.1C (80.1C)"
run_cover 7 "SEN_C07" "Signed negative temperature (0xFFFF)"
run_cover 8 "SEN_C08" "Unmapped address 0x010 read completion"

echo "Sensor Cover runs completed successfully."

