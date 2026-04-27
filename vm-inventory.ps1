# ═══════════════════════════════════════════════════════════
# Script 1 — VM Inventory Report
# What it does: Gets all VMs in your subscription with full
#               details and exports to a CSV report
# When to use:  Daily/weekly reporting, cost reviews,
#               compliance audits
# ═══════════════════════════════════════════════════════════

# Connect to Azure (skip if already connected)
$context = Get-AzContext
if (-not $context) {
    Connect-AzAccount
}

Write-Host "Fetching all VMs in subscription..." -ForegroundColor Cyan

# Get all VMs with their power state
$vms = Get-AzVM -Status

# Check if any VMs found
if ($vms.Count -eq 0) {
    Write-Host "No VMs found in subscription." -ForegroundColor Yellow
    exit
}

Write-Host "Found $($vms.Count) VMs. Building report..." -ForegroundColor Green

# Build the report — one row per VM
$report = foreach ($vm in $vms) {

    # Get power state safely
    $powerState = "Unknown"
    if ($vm.Statuses) {
        $powerStateStatus = $vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }
        if ($powerStateStatus) {
            $powerState = $powerStateStatus.DisplayStatus
        }
    }

    # Get OS type
    $osType = $vm.StorageProfile.OsDisk.OsType

    # Get tags safely
    $envTag   = if ($vm.Tags.Environment) { $vm.Tags.Environment } else { "Not Tagged" }
    $ownerTag = if ($vm.Tags.Owner)       { $vm.Tags.Owner }       else { "Not Tagged" }

    # Build one row
    [PSCustomObject]@{
        VMName        = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        Location      = $vm.Location
        Size          = $vm.HardwareProfile.VmSize
        PowerState    = $powerState
        OSType        = $osType
        Environment   = $envTag
        Owner         = $ownerTag
        SubscriptionId = (Get-AzContext).Subscription.Id
    }
}

# Show in terminal
Write-Host "`n=== VM INVENTORY REPORT ===" -ForegroundColor Yellow
$report | Format-Table -AutoSize

# Export to CSV
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outputPath = ".\vm-inventory-$timestamp.csv"
$report | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "`nReport saved to: $outputPath" -ForegroundColor Green
Write-Host "Total VMs: $($report.Count)" -ForegroundColor Green