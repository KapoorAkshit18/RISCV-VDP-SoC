$mutants = @(
    "M01_nn_base_addr.v",
    "M03_ready_routing.v",
    "M04_rdata_routing.v",
    "M05_write_ctrl.v",
    "M06_strobe_prop.v",
    "M07_periph_valid.v",
    "M08_addr_window.v",
    "M09_ram_addr.v",
    "M10_unmapped.v"
)

$results = [ordered]@{}

foreach ($mutant in $mutants) {
    Write-Host "Testing $mutant..."
    Copy-Item "mutants\soc_mem_interconnect\$mutant" "..\fault_models\soc_mem_interconnect.v" -Force
    
    # Run simulation
    vlog -sv +acc -work work_uvm -f filelist_uvm.f > $null
    vopt +acc -L xpm work_uvm.tb_cpu_soc_ram_top work_uvm.glbl -o tb_uvm_opt_active -work work_uvm > $null
    $log = vsim -c -sv_lib "../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard/tpu_ref" tb_uvm_opt_active -work work_uvm +UVM_TESTNAME=soc_active_regression_test +UVM_MODE=ACTIVE +UVM_VERBOSITY=UVM_LOW -do "run -all; quit -f"
    
    # Check if timeout or error
    $uvm_errors = 0
    $fatal = $false
    $timeout = $true
    
    foreach ($line in $log) {
        if ($line -match 'UVM_ERROR :\s+(\d+)') {
            $uvm_errors = [int]$matches[1]
        }
        if ($line -match 'UVM_FATAL :\s+(\d+)') {
            if ([int]$matches[1] -gt 0) { $fatal = $true }
        }
        if ($line -match 'TEST_DONE') {
            $timeout = $false
        }
    }
    
    if ($timeout) {
        Write-Host "Result: TIMEOUT (FAIL) -> DETECTED"
        $results[$mutant] = "FAIL (TIMEOUT)"
    } elseif ($uvm_errors -gt 0 -or $fatal) {
        Write-Host "Result: UVM_ERROR = $uvm_errors (FAIL) -> DETECTED"
        $results[$mutant] = "FAIL (UVM_ERROR)"
    } else {
        Write-Host "Result: PASS -> ESCAPED"
        $results[$mutant] = "PASS"
    }
}

$results | Out-String | Write-Host
