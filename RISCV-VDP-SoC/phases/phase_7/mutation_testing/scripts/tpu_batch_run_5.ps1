$mutants = @("M_TPU_05")
$testName = "soc_active_tpu_ral_test"

$resultsFile = "tpu_batch_results.txt"

foreach ($m in $mutants) {
    Write-Host "============================================================"
    Write-Host "Running $m | ACTIVE RAL TEST"
    Write-Host "============================================================"
    
    # Inject mutation by overwriting fault_models/nn_axi_wrapper.v
    Copy-Item -Path "mutants/nn_axi_wrapper/$m.v" -Destination "../fault_models/nn_axi_wrapper.v" -Force
    # Fast compile
    cmd.exe /c "vlog -sv +acc -work work_uvm ../fault_models/nn_axi_wrapper.v > nul 2>&1"
    cmd.exe /c "vopt +acc -L xpm work_uvm.tb_cpu_soc_ram_top work_uvm.glbl -o tb_uvm_opt_active -work work_uvm > nul 2>&1"

    $logFile = "uvm_tpu_active_${m}.log"
    $cmd = "vsim -c -sv_lib `"../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard/tpu_ref`" tb_uvm_opt_active -work work_uvm +UVM_TESTNAME=$testName +UVM_MODE=ACTIVE +UVM_VERBOSITY=UVM_LOW -do `"run -all; quit -f`""
    cmd.exe /c "$cmd > $logFile 2>&1"

    $errors = (Select-String -Path $logFile -Pattern "UVM_ERROR\s*:\s*[1-9]" -Quiet)
    $fatals = (Select-String -Path $logFile -Pattern "UVM_FATAL\s*:\s*[1-9]" -Quiet)
    $status = if ($errors -or $fatals) { "DETECTED" } else { "ESCAPED/EQUIVALENT" }
    
    "$m ACTIVE RAL: $status" | Out-File -Append $resultsFile -Encoding ascii
    Write-Host "$m ACTIVE RAL: $status"
}

# Restore Golden at the end
Copy-Item -Path "../fault_models/nn_axi_wrapper.v.golden" -Destination "../fault_models/nn_axi_wrapper.v" -Force
