# ═══════════════════════════════════════════════════════════
# Script 4 — Dev VM Auto-Shutdown
# What it does: Finds all VMs tagged Environment=Development
#               that are still running after 20:00 IST
#               and deallocates them automatically
# When to use:  Schedule via Task Scheduler to run at 20:00
#               daily — saves money overnight
# ═══════════════════════════════════════════════════════════

param(
    [int]$ShutdownHourIST = 20,    # Shutdown after 8 PM IST
    [switch]$WhatIf = $false       # Set to $true to preview without shutting down
)

$context = Get-AzContext
if (-not $context) {
    # For scheduled task — use service principal or managed identity
    # For manual run — interactive login
    Connect-AzAccount
}

# Get current time in IST (UTC+5:30)
$utcNow  = [System.DateTime]::UtcNow
$istNow  = $utcNow.AddHours(5).AddMinutes(30)
$istHour = $istNow.Hour

Write-Host "Current IST time: $($istNow.ToString('yyyy-MM-dd HH:mm')) IST" -ForegroundColor Cyan
Write-Host "Shutdown threshold: After $ShutdownHourIST:00 IST" -ForegroundColor Cyan

if ($istHour -lt $ShutdownHourIST) {
    Write-Host "Current time ($istHour:00 IST) is before shutdown threshold ($ShutdownHourIST:00 IST)." -ForegroundColor Yellow
    Write-Host "No action taken. Run after $ShutdownHourIST:00 IST or use -ShutdownHourIST 0 to force." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nScanning for running Development VMs..." -ForegroundColor Cyan

# Get all VMs with status
$allVMs = Get-AzVM -Status

# Filter: tag Environment=Development AND currently running
$devRunningVMs = $allVMs | Where-Object {
    $_.Tags.Environment -eq "Development" -and
    $_.Statuses | Where-Object { $_.Code -eq "PowerState/running" }
}

if ($devRunningVMs.Count -eq 0) {
    Write-Host "✅ No running Development VMs found. Nothing to shut down." -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($devRunningVMs.Count) running Development VMs:" -ForegroundColor Yellow
$devRunningVMs | Select-Object Name, ResourceGroupName, Location | Format-Table -AutoSize

$shutdownResults = @()

foreach ($vm in $devRunningVMs) {

    if ($WhatIf) {
        Write-Host "WHATIF: Would deallocate $($vm.Name) in $($vm.ResourceGroupName)" -ForegroundColor Magenta
        $shutdownResults += [PSCustomObject]@{
            VMName        = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            Action        = "WHATIF — Would deallocate"
            Timestamp     = $istNow.ToString("yyyy-MM-dd HH:mm")
        }
    } else {
        try {
            Write-Host "Deallocating $($vm.Name)..." -ForegroundColor Yellow
            Stop-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force | Out-Null
            Write-Host "  ✅ Deallocated: $($vm.Name)" -ForegroundColor Green
            $shutdownResults += [PSCustomObject]@{
                VMName        = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action        = "DEALLOCATED"
                Timestamp     = $istNow.ToString("yyyy-MM-dd HH:mm")
            }
        }
        catch {
            Write-Host "  ❌ Failed to deallocate $($vm.Name): $($_.Exception.Message)" -ForegroundColor Red
            $shutdownResults += [PSCustomObject]@{
                VMName        = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action        = "FAILED — $($_.Exception.Message)"
                Timestamp     = $istNow.ToString("yyyy-MM-dd HH:mm")
            }
        }
    }
}

# Save log
$logPath = ".\shutdown-log-$(Get-Date -Format 'yyyy-MM-dd').csv"
$shutdownResults | Export-Csv -Path $logPath -NoTypeInformation -Append

Write-Host "`n=== SHUTDOWN SUMMARY ===" -ForegroundColor Cyan
$shutdownResults | Format-Table -AutoSize
Write-Host "Log saved to: $logPath" -ForegroundColor Yellow