$ErrorActionPreference = "Stop"

$workspace = "c:\RISCV-VDP-SoC\RISCV-VDP-SoC\phases\phase_7\mutation_testing"
Set-Location $workspace

$fw1 = "../../phase_5/Old2New_SoC/firmware_test03/firmware.hex"
$fw2 = "../../phase_5/Old2New_SoC/firmware_test_04/firmware.hex"

# Format: MutantID, Firmware (1 or 2), Flow (Dir or UVM), UVMTest (if UVM)
$runs = @(
    # M02 (Sensor local-addr) -> Only FW2
    @("M02", "FW2", "DIR", ""),
    @("M02", "FW2", "UVM", "soc_sensor_test"),

    # M06 (RAM strobe) -> FW1 & FW2
    @("M06", "FW1", "DIR", ""),
    @("M06", "FW1", "UVM", "soc_tpu_test"),
    @("M06", "FW2", "DIR", ""),
    @("M06", "FW2", "UVM", "soc_sensor_test"),

    # M08 (Sensor base-addr) -> Only FW2
    @("M08", "FW2", "DIR", ""),
    @("M08", "FW2", "UVM", "soc_sensor_test"),

    # M09 (RAM addr corruption) -> FW1 & FW2
    @("M09", "FW1", "DIR", ""),
    @("M09", "FW1", "UVM", "soc_tpu_test"),
    @("M09", "FW2", "DIR", ""),
    @("M09", "FW2", "UVM", "soc_sensor_test")
)

# File to append results to
$resultsLog = "$workspace\batch_run_results.txt"
"--- BATCH RUN START ---" | Out-File -FilePath $resultsLog

foreach ($run in $runs) {
    $mutant = $run[0]
    $fwType = $run[1]
    $flow   = $run[2]
    $uvmTest = $run[3]
    
    $fwPath = if ($fwType -eq "FW1") { $fw1 } else { $fw2 }
    
    $logFile = "$workspace\logs\batch_${mutant}_${fwType}_${flow}.log"
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "Running $mutant | $fwType | $flow" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    if ($flow -eq "DIR") {
        $cmd = "make mutation_directed MUTANT=$mutant FW=$fwPath"
    } else {
        $cmd = "make mutation_uvm MUTANT=$mutant FW=$fwPath TEST=$uvmTest"
    }
    
    Write-Host "> $cmd"
    
    # Run the make command
    $fullCmd = "make " + $cmd.Substring(5)
    cmd.exe /c "$fullCmd > `"$logFile`" 2>&1"

    # Analyze the log
    $content = Get-Content $logFile -Raw
    $detection = "UNKNOWN"
    $reason = ""
    
    if ($flow -eq "DIR") {
        if ($content -match "PHASE 5 FAIL") {
            $detection = "DETECTED"
            $reason = "FW FAILURE MARKER"
        } elseif ($content -match "PHASE 5 TIMEOUT") {
            $detection = "DETECTED"
            $reason = "TIMEOUT"
        } elseif ($content -match "PHASE 5 PASS") {
            $detection = "ESCAPED"
            $reason = "ALL TESTS PASSED"
        } else {
            $detection = "INVALID/ERROR"
        }
    } else { # UVM
        $errCount = 0
        $fatalCount = 0
        if ($content -match "UVM_ERROR :\s+(\d+)") { $errCount = [int]$matches[1] }
        if ($content -match "UVM_FATAL :\s+(\d+)") { $fatalCount = [int]$matches[1] }
        
        if ($errCount -gt 0 -or $fatalCount -gt 0) {
            $detection = "DETECTED"
            $reason = "$errCount ERROR(s), $fatalCount FATAL(s)"
        } elseif ($content -match "\`$finish" -or $content -match "UVM Report Summary") {
            $detection = "ESCAPED"
            $reason = "0 ERRORS/FATALS"
        } else {
            $detection = "INVALID/ERROR (or Hang)"
        }
    }
    
    $resultStr = "[${mutant}] [${fwType}] [${flow}] => ${detection} (${reason})"
    Write-Host $resultStr -ForegroundColor Yellow
    $resultStr | Out-File -FilePath $resultsLog -Append
    
    # ALWAYS restore golden after each run
    Write-Host "> make restore"
    Start-Process -FilePath "make" -ArgumentList "restore" -NoNewWindow -Wait -RedirectStandardOutput "$workspace\logs\restore.log"
}

Write-Host "`nAll Batch Runs Completed!" -ForegroundColor Green
