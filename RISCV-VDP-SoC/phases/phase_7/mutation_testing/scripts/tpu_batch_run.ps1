$mutants    = @("GOLDEN", "M_TPU_01", "M_TPU_02", "M_TPU_03", "M_TPU_04", "M_TPU_05")
$ralTest    = "soc_active_tpu_ral_test"
$fwHex      = "../../phase_5/Old2New_SoC/firmware_test03/firmware.hex"
$fwTest     = "soc_tpu_test"
$tpuRef     = "../../phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard/tpu_ref"
$goldenSrc  = "../../fault_models/nn_axi_wrapper.v.golden"
$targetRTL  = "../../fault_models/nn_axi_wrapper.v"
$resultsFile = "tpu_batch_results.txt"

"--- TPU BATCH RUN START ---" | Out-File $resultsFile -Encoding ascii
"mutant,active_ral,fw_directed,fw_uvm" | Out-File -Append $resultsFile -Encoding ascii

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
function Inject-Mutant($m) {
    if ($m -eq "GOLDEN") {
        Copy-Item -Path $goldenSrc -Destination $targetRTL -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $goldenSrc)) {
            Copy-Item -Path $targetRTL -Destination $goldenSrc -Force
        }
    } else {
        Copy-Item -Path "../mutants/nn_axi_wrapper/$m.v" -Destination $targetRTL -Force
    }
    cmd.exe /c "vlog -sv +acc -work ../work_uvm $targetRTL > nul 2>&1"
    cmd.exe /c "vopt +acc -L xpm work_uvm.tb_cpu_soc_ram_top work_uvm.glbl -o tb_uvm_opt_active -work ../work_uvm > nul 2>&1"
}

function Get-Status($logFile) {
    $errors = Select-String -Path $logFile -Pattern "UVM_ERROR\s*:\s*[1-9]" -Quiet
    $fatals = Select-String -Path $logFile -Pattern "UVM_FATAL\s*:\s*[1-9]" -Quiet
    if ($errors -or $fatals) { return "DETECTED" } else { return "ESCAPED/EQUIVALENT" }
}

# ---------------------------------------------------------------
# Compile base once
# ---------------------------------------------------------------
Write-Host "=== Compiling base ==="
cmd.exe /c "make -C .. uvm_compile > nul 2>&1"

# ---------------------------------------------------------------
# Per-mutant loop
# ---------------------------------------------------------------
foreach ($m in $mutants) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Mutant: $m"
    Write-Host "============================================================"

    Inject-Mutant $m

    # --- Flow 1: Active UVM RAL (no firmware, CPU in reset) ---
    $logRal = "uvm_tpu_active_${m}.log"
    $cmd = "vsim -c -sv_lib `"$tpuRef`" tb_uvm_opt_active -work ../work_uvm +UVM_TESTNAME=$ralTest +UVM_VERBOSITY=UVM_LOW -do `"run -all; quit -f`""
    cmd.exe /c "$cmd > $logRal 2>&1"
    $statusRal = Get-Status $logRal
    Write-Host "  Active RAL : $statusRal"

    # --- Flow 2: Firmware directed (CPU executes firmware_test03) ---
    $logFwDir = "fw_directed_${m}.log"
    cmd.exe /c "vlog -sv +acc -work ../work_directed $targetRTL > nul 2>&1"
    cmd.exe /c "vopt +acc -L xpm work_directed.tb_cpu_soc_ram_top work_directed.glbl -o tb_dir_opt_mut -work ../work_directed > nul 2>&1"
    $cmdDir = "vsim -c tb_dir_opt_mut -work ../work_directed +FW_HEX=$fwHex -do `"run -all; quit -f`""
    cmd.exe /c "$cmdDir > $logFwDir 2>&1"
    $fwPass    = Select-String -Path $logFwDir -Pattern "MARK_SUCCESS|33333333" -Quiet
    $fwFail    = Select-String -Path $logFwDir -Pattern "MARK_ERROR|DEAD0001"   -Quiet
    $statusFwDir = if ($fwFail) { "DETECTED" } elseif ($fwPass) { "ESCAPED" } else { "UNOBSERVABLE" }
    Write-Host "  FW Directed: $statusFwDir"

    # --- Flow 3: Firmware UVM passive (firmware + UVM monitors + scoreboard) ---
    $logFwUvm = "fw_uvm_${m}.log"
    $cmdUvm = "vsim -c -sv_lib `"$tpuRef`" tb_uvm_opt_active -work ../work_uvm +UVM_TESTNAME=$fwTest +FW_HEX=$fwHex +UVM_VERBOSITY=UVM_NONE -do `"run -all; quit -f`""
    cmd.exe /c "$cmdUvm > $logFwUvm 2>&1"
    $statusFwUvm = Get-Status $logFwUvm
    Write-Host "  FW UVM     : $statusFwUvm"

    # Record
    "$m,$statusRal,$statusFwDir,$statusFwUvm" | Out-File -Append $resultsFile -Encoding ascii
}

# Restore golden
Copy-Item -Path $goldenSrc -Destination $targetRTL -Force
Write-Host ""
Write-Host "=== Golden restored. Results in $resultsFile ==="
