# ═══════════════════════════════════════════════════════════
# Script 2 — Orphan Hunter
# What it does: Finds unattached managed disks and unused
#               public IPs — resources wasting money
# When to use:  Weekly cost optimisation review
#               Run before monthly billing cycle
# ═══════════════════════════════════════════════════════════

$context = Get-AzContext
if (-not $context) { Connect-AzAccount }

Write-Host "Scanning for orphaned resources..." -ForegroundColor Cyan

# ── PART 1: Unattached Managed Disks ─────────────────────
Write-Host "`nChecking for unattached managed disks..." -ForegroundColor Yellow

$allDisks = Get-AzDisk

# Filter: disks where ManagedBy is empty = not attached to any VM
$orphanDisks = $allDisks | Where-Object { [string]::IsNullOrEmpty($_.ManagedBy) }

$diskReport = foreach ($disk in $orphanDisks) {

    # Estimate monthly cost (approximate)
    $monthlyCost = switch ($disk.Sku.Name) {
        "Standard_LRS"  { [math]::Round($disk.DiskSizeGB * 0.04,  2) }
        "StandardSSD_LRS" { [math]::Round($disk.DiskSizeGB * 0.075, 2) }
        "Premium_LRS"   { [math]::Round($disk.DiskSizeGB * 0.135, 2) }
        default         { [math]::Round($disk.DiskSizeGB * 0.04,  2) }
    }

    [PSCustomObject]@{
        ResourceType    = "Managed Disk"
        Name            = $disk.Name
        ResourceGroup   = $disk.ResourceGroupName
        Location        = $disk.Location
        SizeGB          = $disk.DiskSizeGB
        SKU             = $disk.Sku.Name
        EstMonthlyCost  = "`$$monthlyCost USD"
        CreatedDate     = $disk.TimeCreated
        Status          = "ORPHANED — Not attached to any VM"
    }
}

# ── PART 2: Unused Public IPs ─────────────────────────────
Write-Host "Checking for unused public IP addresses..." -ForegroundColor Yellow

$allPublicIPs = Get-AzPublicIpAddress

# Filter: public IPs where IpConfiguration is null = not associated
$orphanIPs = $allPublicIPs | Where-Object { $null -eq $_.IpConfiguration }

$ipReport = foreach ($pip in $orphanIPs) {

    # Standard SKU static IPs cost ~$0.005/hour = ~$3.60/month
    $monthlyCost = switch ($pip.Sku.Name) {
        "Standard" { 3.60 }
        "Basic"    { 0 }
        default    { 3.60 }
    }

    [PSCustomObject]@{
        ResourceType    = "Public IP Address"
        Name            = $pip.Name
        ResourceGroup   = $pip.ResourceGroupName
        Location        = $pip.Location
        SizeGB          = "N/A"
        SKU             = $pip.Sku.Name
        EstMonthlyCost  = "`$$monthlyCost USD"
        CreatedDate     = "N/A"
        Status          = "ORPHANED — Not associated with any resource"
    }
}

# ── COMBINE RESULTS ───────────────────────────────────────
$allOrphans = @($diskReport) + @($ipReport)

if ($allOrphans.Count -eq 0) {
    Write-Host "`n✅ No orphaned resources found. Your subscription is clean!" -ForegroundColor Green
} else {
    Write-Host "`n=== ORPHANED RESOURCES FOUND ===" -ForegroundColor Red
    $allOrphans | Format-Table -AutoSize

    # Calculate total wasted cost
    $totalWaste = ($allOrphans | ForEach-Object {
        [decimal]($_.EstMonthlyCost -replace '[^0-9.]', '')
    } | Measure-Object -Sum).Sum

    Write-Host "Total orphaned resources: $($allOrphans.Count)" -ForegroundColor Red
    Write-Host "Estimated monthly waste: `$$totalWaste USD" -ForegroundColor Red

    # Export report
    $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $outputPath = ".\orphan-report-$timestamp.csv"
    $allOrphans | Export-Csv -Path $outputPath -NoTypeInformation
    Write-Host "Report saved to: $outputPath" -ForegroundColor Yellow
    Write-Host "`nReview the report and DELETE these resources to save money." -ForegroundColor Yellow
}