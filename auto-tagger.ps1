# ═══════════════════════════════════════════════════════════
# Script 3 — Auto-Tagger
# What it does: Reads a CSV of resources and tags and applies
#               those tags to each resource in Azure
# When to use:  Bulk tagging after cloud migrations,
#               enforcing tagging standards across teams
# ═══════════════════════════════════════════════════════════

param(
    [string]$CsvPath = ".\resources-to-tag.csv"
)

$context = Get-AzContext
if (-not $context) { Connect-AzAccount }

# Check CSV exists
if (-not (Test-Path $CsvPath)) {
    Write-Host "ERROR: CSV file not found at $CsvPath" -ForegroundColor Red
    exit 1
}

# Read the CSV
$resources = Import-Csv -Path $CsvPath
Write-Host "Loaded $($resources.Count) resources from CSV" -ForegroundColor Cyan

$successCount = 0
$failCount    = 0
$results      = @()

foreach ($resource in $resources) {

    Write-Host "`nProcessing: $($resource.ResourceName)..." -ForegroundColor Yellow

    try {
        # Build tags hashtable from CSV columns
        $tags = @{
            Environment = $resource.Environment
            Owner       = $resource.Owner
            CostCenter  = $resource.CostCenter
            TaggedBy    = "AutoTagger-Script"
            TaggedDate  = (Get-Date -Format "yyyy-MM-dd")
        }

        # Try to find the resource — first check if it is a Resource Group
        $azResource = $null

        # Check if it is a Resource Group
        $rg = Get-AzResourceGroup -Name $resource.ResourceName -ErrorAction SilentlyContinue
        if ($rg) {
            # It is a Resource Group — tag it directly
            Set-AzResourceGroup -Name $resource.ResourceName -Tag $tags | Out-Null
            Write-Host "  ✅ Tagged Resource Group: $($resource.ResourceName)" -ForegroundColor Green
            $successCount++
            $results += [PSCustomObject]@{
                ResourceName  = $resource.ResourceName
                ResourceGroup = $resource.ResourceGroup
                Status        = "SUCCESS"
                Type          = "ResourceGroup"
            }
        } else {
            # It is a regular resource — find it by name in the specified RG
            $azResource = Get-AzResource `
                -ResourceGroupName $resource.ResourceGroup `
                -Name $resource.ResourceName `
                -ErrorAction SilentlyContinue

            if ($azResource) {
                # Get existing tags and merge — do not overwrite existing tags
                $existingTags = $azResource.Tags
                if (-not $existingTags) { $existingTags = @{} }

                # Merge new tags with existing
                foreach ($key in $tags.Keys) {
                    $existingTags[$key] = $tags[$key]
                }

                Set-AzResource -ResourceId $azResource.Id -Tag $existingTags -Force | Out-Null
                Write-Host "  ✅ Tagged resource: $($resource.ResourceName)" -ForegroundColor Green
                $successCount++
                $results += [PSCustomObject]@{
                    ResourceName  = $resource.ResourceName
                    ResourceGroup = $resource.ResourceGroup
                    Status        = "SUCCESS"
                    Type          = $azResource.ResourceType
                }
            } else {
                Write-Host "  ❌ Resource not found: $($resource.ResourceName) in $($resource.ResourceGroup)" -ForegroundColor Red
                $failCount++
                $results += [PSCustomObject]@{
                    ResourceName  = $resource.ResourceName
                    ResourceGroup = $resource.ResourceGroup
                    Status        = "FAILED — Resource not found"
                    Type          = "Unknown"
                }
            }
        }
    }
    catch {
        Write-Host "  ❌ Error tagging $($resource.ResourceName): $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        $results += [PSCustomObject]@{
            ResourceName  = $resource.ResourceName
            ResourceGroup = $resource.ResourceGroup
            Status        = "FAILED — $($_.Exception.Message)"
            Type          = "Error"
        }
    }
}

# Summary
Write-Host "`n=== TAGGING SUMMARY ===" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed:     $failCount"    -ForegroundColor Red

$results | Format-Table -AutoSize

# Export results
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outputPath = ".\tagging-results-$timestamp.csv"
$results | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "Results saved to: $outputPath" -ForegroundColor Yellow