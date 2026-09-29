$mutants = @("GOLDEN", "M01", "M03", "M04", "M05", "M06", "M07", "M08", "M09", "M10")
$testName = "soc_active_campaign_test"
$fw = "../../phase_5/Old2New_SoC/firmware_test_04/firmware.hex" # Just a dummy FW, CPU is off

# Compile base
cmd.exe /c "make uvm_compile > nul 2>&1"

$resultsFile = "active_batch_results.txt"
"--- ACTIVE BATCH RUN START ---" | Out-File $resultsFile -Encoding ascii

foreach ($m in $mutants) {
    Write-Host "============================================================"
    Write-Host "Running $m | ACTIVE"
    Write-Host "============================================================"
    
    if ($m -ne "GOLDEN") {
        cmd.exe /c "make inject MUTANT=$m > nul 2>&1"
        # Fast compile
        cmd.exe /c "vlog -sv +acc -work work_uvm ../fault_models/soc_mem_interconnect.v > nul 2>&1"
        cmd.exe /c "vopt +acc -L xpm work_uvm.tb_cpu_soc_ram_top work_uvm.glbl -o tb_uvm_opt_active -work work_uvm > nul 2>&1"
    }

    $logFile = "uvm_active_${m}.log"
    $cmd = "vsim -c -sv_lib `"../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard/tpu_ref`" tb_uvm_opt_active -work work_uvm +UVM_TESTNAME=$testName +UVM_MODE=ACTIVE +UVM_VERBOSITY=UVM_LOW -do `"run -all; quit -f`""
    cmd.exe /c "$cmd > $logFile 2>&1"
    
    $logContent = Get-Content $logFile -Raw
    
    $status = "ESCAPED"
    
    # Check for UVM_ERROR with DETECTED keyword
    if ($logContent -match "DETECTED:") {
        $status = "DETECTED (UVM_ERROR)"
    }
    elseif ($logContent -match "TIMEOUT" -or $logContent -match "No m_ready") {
        $status = "DETECTED (TIMEOUT)"
    }
    elseif ($logContent -match "UVM_ERROR") {
        $status = "DETECTED (UVM_ERROR - Other)"
    }
    
    $resultStr = "[$m] [ACTIVE] => $status"
    Write-Host $resultStr
    $resultStr | Out-File $resultsFile -Append -Encoding ascii
    
    if ($m -ne "GOLDEN") {
        cmd.exe /c "make restore > nul 2>&1"
        # Restore compile
        cmd.exe /c "vlog -sv +acc -work work_uvm ../fault_models/soc_mem_interconnect.v > nul 2>&1"
        cmd.exe /c "vopt +acc -L xpm work_uvm.tb_cpu_soc_ram_top work_uvm.glbl -o tb_uvm_opt_active -work work_uvm > nul 2>&1"
    }
}
Write-Host "All Active Batch Runs Completed!"
