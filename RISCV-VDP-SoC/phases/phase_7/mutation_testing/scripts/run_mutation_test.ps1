#!/usr/bin/env pwsh
# ============================================================
# Phase 7 — Mutation Testing Automation Script
#
# Usage:
#   .\run_mutation_test.ps1 -Mutant M01           # Single mutant
#   .\run_mutation_test.ps1 -All                   # All mutants
#   .\run_mutation_test.ps1 -Mutant M01 -DryRun    # Dry run
#
# Requirements:
#   - Questa/ModelSim in PATH (vlog, vopt, vsim)
#   - Xilinx Vivado glbl.v accessible
#   - tpu_ref.dll in the UVM scoreboard path
#
# ============================================================

param(
    [string]$Mutant = "",
    [switch]$All,
    [switch]$DryRun,
    [switch]$DirectedOnly,
    [switch]$UvmOnly
)

# Paths
$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$MutationDir   = Split-Path -Parent $ScriptDir  # mutation_testing/
$Phase7        = Split-Path -Parent $MutationDir # phase_7/
$FaultModels   = Join-Path $Phase7 "fault_models"
$MutantsDir    = Join-Path $MutationDir "mutants\soc_mem_interconnect"
$LogsDir       = Join-Path $MutationDir "logs"
$ResultsDir    = Join-Path $MutationDir "results"
$GoldenBackup  = Join-Path $MutationDir "golden\soc_mem_interconnect_golden.v"
$GoldenTarget  = Join-Path $FaultModels "soc_mem_interconnect.v"
$GoldenHash    = "7695FBE6D53A69E15B80F3DDDF57C520CA2ABE7B0204E1118577425519100D3E"

# Mutant list
$AllMutants = @(
    @{ ID="M01"; File="M01_nn_base_addr.v";   Desc="NN/TPU base-address decode error" },
    @{ ID="M02"; File="M02_local_addr.v";      Desc="Peripheral local-address translation error" },
    @{ ID="M03"; File="M03_ready_routing.v";   Desc="Wrong ready-response routing" },
    @{ ID="M04"; File="M04_rdata_routing.v";   Desc="Wrong read-data response routing" },
    @{ ID="M05"; File="M05_write_ctrl.v";      Desc="Write-control propagation error" },
    @{ ID="M06"; File="M06_strobe_prop.v";     Desc="Strobe propagation error" },
    @{ ID="M07"; File="M07_periph_valid.v";    Desc="Incorrect peripheral valid assertion" },
    @{ ID="M08"; File="M08_addr_window.v";     Desc="Incorrect peripheral address-window decode" },
    @{ ID="M09"; File="M09_ram_addr.v";        Desc="RAM address corruption" },
    @{ ID="M10"; File="M10_unmapped.v";        Desc="Incorrect unmapped-access completion" }
)


# ============================================================
# Functions
# ============================================================

function Test-GoldenIntegrity {
    $hash = (Get-FileHash $GoldenTarget -Algorithm SHA256).Hash
    if ($hash -eq $GoldenHash) {
        Write-Host "[SAFETY] Golden RTL integrity: PASS" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[SAFETY] Golden RTL integrity: FAIL" -ForegroundColor Red
        Write-Host "  Expected: $GoldenHash"
        Write-Host "  Got:      $hash"
        return $false
    }
}

function Restore-Golden {
    Write-Host "[RESTORE] Restoring golden soc_mem_interconnect.v ..."
    Copy-Item $GoldenBackup $GoldenTarget -Force
    if (Test-GoldenIntegrity) {
        Write-Host "[RESTORE] Golden restored successfully." -ForegroundColor Green
    } else {
        Write-Host "[RESTORE] CRITICAL: Golden restore failed!" -ForegroundColor Red
        throw "Golden restore failed. Manual intervention required."
    }
}

function Inject-Mutant {
    param([string]$MutantFile)

    $src = Join-Path $MutantsDir $MutantFile
    if (-not (Test-Path $src)) {
        Write-Host "[ERROR] Mutant file not found: $src" -ForegroundColor Red
        return $false
    }

    Write-Host "[INJECT] Copying $MutantFile -> fault_models/soc_mem_interconnect.v"
    Copy-Item $src $GoldenTarget -Force

    # Verify the file changed
    $newHash = (Get-FileHash $GoldenTarget -Algorithm SHA256).Hash
    if ($newHash -eq $GoldenHash) {
        Write-Host "[ERROR] Mutant injection had no effect (hash unchanged)!" -ForegroundColor Red
        return $false
    }
    Write-Host "[INJECT] Mutant injected. New hash: $newHash" -ForegroundColor Yellow
    return $true
}

function Run-DirectedTest {
    param([string]$MutantID)

    $logFile = Join-Path $LogsDir "directed\${MutantID}_directed.log"
    Write-Host "[DIRECTED] Compiling and running directed test for $MutantID ..."

    if ($DryRun) {
        Write-Host "[DRY RUN] Would run: make -C $MutationDir directed_run" -ForegroundColor Cyan
        return @{ Compile="DRY_RUN"; Test="DRY_RUN"; Detection="DRY_RUN" }
    }

    Push-Location $MutationDir
    try {
        # Clean previous work
        if (Test-Path "work_directed") { Remove-Item -Recurse -Force "work_directed" }

        # Compile
        $compileOutput = & make directed_compile 2>&1 | Out-String
        $compileOutput | Out-File $logFile -Encoding utf8

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[DIRECTED] Compilation FAILED for $MutantID" -ForegroundColor Red
            return @{ Compile="FAIL"; Test="N/A"; Detection="INVALID" }
        }

        # Run
        $runOutput = & make directed_run 2>&1 | Out-String
        $runOutput | Out-File $logFile -Append -Encoding utf8

        # Analyze result
        $compileResult = "PASS"
        $testResult = "UNKNOWN"
        $detection = "UNKNOWN"

        if ($runOutput -match "ALL TESTS PASSED") {
            $testResult = "ALL_PASS"
            $detection = "ESCAPED"
        } elseif ($runOutput -match "FAILED") {
            $testResult = "FAIL"
            $detection = "DETECTED"
        } elseif ($runOutput -match "Error") {
            $testResult = "ERROR"
            $detection = "DETECTED"
        }

        Write-Host "[DIRECTED] $MutantID result: $detection" -ForegroundColor $(if ($detection -eq "DETECTED") { "Green" } else { "Yellow" })

        return @{ Compile=$compileResult; Test=$testResult; Detection=$detection }
    } finally {
        Pop-Location
    }
}

function Run-UvmTest {
    param([string]$MutantID)

    $logFile = Join-Path $LogsDir "uvm\${MutantID}_uvm.log"
    Write-Host "[UVM] Compiling and running UVM test for $MutantID ..."

    if ($DryRun) {
        Write-Host "[DRY RUN] Would run: make -C $MutationDir uvm_run" -ForegroundColor Cyan
        return @{ Compile="DRY_RUN"; Test="DRY_RUN"; Detection="DRY_RUN" }
    }

    Push-Location $MutationDir
    try {
        # Clean previous work
        if (Test-Path "work_uvm") { Remove-Item -Recurse -Force "work_uvm" }

        # Compile
        $compileOutput = & make uvm_compile 2>&1 | Out-String
        $compileOutput | Out-File $logFile -Encoding utf8

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[UVM] Compilation FAILED for $MutantID" -ForegroundColor Red
            return @{ Compile="FAIL"; Test="N/A"; Detection="INVALID" }
        }

        # Optimize + Run
        $runOutput = & make uvm_optimize uvm_run 2>&1 | Out-String
        $runOutput | Out-File $logFile -Append -Encoding utf8

        # Analyze result
        $compileResult = "PASS"
        $testResult = "UNKNOWN"
        $detection = "UNKNOWN"

        if ($runOutput -match "UVM_ERROR\s*:\s*0" -and $runOutput -match "UVM_FATAL\s*:\s*0") {
            $testResult = "UVM_PASS"
            $detection = "ESCAPED"
        } elseif ($runOutput -match "UVM_ERROR|UVM_FATAL") {
            $testResult = "UVM_FAIL"
            $detection = "DETECTED"
        } elseif ($runOutput -match "TIMEOUT|timeout") {
            $testResult = "TIMEOUT"
            $detection = "DETECTED"
        }

        Write-Host "[UVM] $MutantID result: $detection" -ForegroundColor $(if ($detection -eq "DETECTED") { "Green" } else { "Yellow" })

        return @{ Compile=$compileResult; Test=$testResult; Detection=$detection }
    } finally {
        Pop-Location
    }
}

function Run-SingleMutant {
    param([hashtable]$MutantInfo)

    $id   = $MutantInfo.ID
    $file = $MutantInfo.File
    $desc = $MutantInfo.Desc

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  MUTANT: $id — $desc"
    Write-Host "================================================================" -ForegroundColor Cyan

    # Safety check before starting
    if (-not (Test-GoldenIntegrity)) {
        Write-Host "[ABORT] Golden integrity check failed before $id. Stopping." -ForegroundColor Red
        return $null
    }

    # === DIRECTED TEST ===
    $dirResult = $null
    if (-not $UvmOnly) {
        # Inject mutant
        if (-not (Inject-Mutant $file)) { return $null }

        # Run directed
        $dirResult = Run-DirectedTest $id

        # Restore
        Restore-Golden
    }

    # === UVM TEST ===
    $uvmResult = $null
    if (-not $DirectedOnly) {
        # Verify golden before re-inject
        if (-not (Test-GoldenIntegrity)) {
            Write-Host "[ABORT] Golden integrity failed before UVM inject for $id" -ForegroundColor Red
            return $null
        }

        # Inject mutant again
        if (-not (Inject-Mutant $file)) { return $null }

        # Run UVM
        $uvmResult = Run-UvmTest $id

        # Restore
        Restore-Golden
    }

    return @{
        ID              = $id
        Description     = $desc
        File            = $file
        DirCompile      = if ($dirResult) { $dirResult.Compile } else { "SKIPPED" }
        DirTest         = if ($dirResult) { $dirResult.Test } else { "SKIPPED" }
        DirDetection    = if ($dirResult) { $dirResult.Detection } else { "SKIPPED" }
        UvmCompile      = if ($uvmResult) { $uvmResult.Compile } else { "SKIPPED" }
        UvmTest         = if ($uvmResult) { $uvmResult.Test } else { "SKIPPED" }
        UvmDetection    = if ($uvmResult) { $uvmResult.Detection } else { "SKIPPED" }
    }
}


# ============================================================
# Main
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "  PHASE 7: RTL MUTATION TESTING CAMPAIGN"
Write-Host "  Target: soc_mem_interconnect"
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "============================================================"
Write-Host ""

# Determine which mutants to run
$mutantsToRun = @()
if ($All) {
    $mutantsToRun = $AllMutants
} elseif ($Mutant) {
    $found = $AllMutants | Where-Object { $_.ID -eq $Mutant }
    if ($found) {
        $mutantsToRun = @($found)
    } else {
        Write-Host "[ERROR] Unknown mutant: $Mutant" -ForegroundColor Red
        Write-Host "Available: $($AllMutants.ID -join ', ')"
        exit 1
    }
} else {
    Write-Host "Usage:"
    Write-Host "  .\run_mutation_test.ps1 -Mutant M01"
    Write-Host "  .\run_mutation_test.ps1 -All"
    Write-Host "  .\run_mutation_test.ps1 -Mutant M01 -DryRun"
    exit 0
}

# Initial golden check
if (-not (Test-GoldenIntegrity)) {
    Write-Host "[ABORT] Initial golden integrity check failed. Cannot proceed." -ForegroundColor Red
    exit 1
}

# Run mutants
$results = @()
foreach ($m in $mutantsToRun) {
    $result = Run-SingleMutant $m
    if ($result) {
        $results += $result
    } else {
        Write-Host "[WARN] Mutant $($m.ID) failed to complete. Restoring golden and continuing." -ForegroundColor Yellow
        Restore-Golden
    }
}

# Final golden check
Write-Host ""
Write-Host "=== FINAL GOLDEN INTEGRITY CHECK ==="
Test-GoldenIntegrity | Out-Null

# Output CSV
$csvFile = Join-Path $ResultsDir "mutation_results.csv"
$csvHeader = "Mutation_ID,Module,Bug_Category,Description,Source_File,Directed_Compile,Directed_Test,Directed_Detection,UVM_Compile,UVM_Test,UVM_Detection,Log_Path_Directed,Log_Path_UVM"

$csvLines = @($csvHeader)
foreach ($r in $results) {
    $line = "$($r.ID),soc_mem_interconnect,$($r.Description),`"$($r.Description)`",$($r.File),$($r.DirCompile),$($r.DirTest),$($r.DirDetection),$($r.UvmCompile),$($r.UvmTest),$($r.UvmDetection),logs/directed/$($r.ID)_directed.log,logs/uvm/$($r.ID)_uvm.log"
    $csvLines += $line
}
$csvLines | Out-File $csvFile -Encoding utf8

Write-Host ""
Write-Host "=== RESULTS SUMMARY ==="
Write-Host "Results saved to: $csvFile"
$results | Format-Table ID, Description, DirDetection, UvmDetection -AutoSize

# Calculate stats
$validDir  = ($results | Where-Object { $_.DirDetection -notin @("INVALID","SKIPPED","DRY_RUN") }).Count
$validUvm  = ($results | Where-Object { $_.UvmDetection -notin @("INVALID","SKIPPED","DRY_RUN") }).Count
$detDir    = ($results | Where-Object { $_.DirDetection -eq "DETECTED" }).Count
$detUvm    = ($results | Where-Object { $_.UvmDetection -eq "DETECTED" }).Count
$escDir    = ($results | Where-Object { $_.DirDetection -eq "ESCAPED" }).Count
$escUvm    = ($results | Where-Object { $_.UvmDetection -eq "ESCAPED" }).Count

Write-Host ""
Write-Host "Directed: $detDir detected / $validDir valid = $(if ($validDir -gt 0) { [math]::Round($detDir/$validDir*100,1) } else { 'N/A' })%"
Write-Host "UVM:      $detUvm detected / $validUvm valid = $(if ($validUvm -gt 0) { [math]::Round($detUvm/$validUvm*100,1) } else { 'N/A' })%"
Write-Host ""
