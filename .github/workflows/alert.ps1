# Initial template from https://discohook.org/

# Process all XML files in catalogs directory
$contentLines = @()

foreach($xmlFile in Get-ChildItem -Path .\catalogs\*.xml –Recurse)
{
    $xmlFileName = $xmlFile.Name
    $baseName = $xmlFile.BaseName
    $warningsFile = "$($xmlFile.Directory)\$($baseName)_warnings.txt"
    $errorsFile = "$($xmlFile.Directory)\$($baseName)_errors.txt"
    
    $hasContent = $false
    $sectionContent = @()
    $hasErrors = $false
    
    # Check for errors file first
    if (Test-Path $errorsFile) {
        $errorsContent = (Get-Content -Path $errorsFile -Raw) -replace "`r`n", "`n"
        if ([string]::IsNullOrWhiteSpace($errorsContent) -eq $false) {
            $sectionContent += $errorsContent
            $hasContent = $true
            $hasErrors = $true
        }
    }
    
    # Check for warnings file
    if (Test-Path $warningsFile) {
        $warningsContent = (Get-Content -Path $warningsFile -Raw) -replace "`r`n", "`n"
        if ([string]::IsNullOrWhiteSpace($warningsContent) -eq $false) {
            if ($hasErrors) {
                $sectionContent += ""
            }
            $sectionContent += $warningsContent
            $hasContent = $true
        }
    }
    
    # Add to content if any warnings or errors found
    if ($hasContent) {
        # Normalize content for Discord
        $sectionContent = $sectionContent -replace '»', '-'

        $contentLines += "## $xmlFileName`n‎"
        $contentLines += $sectionContent
    }
}

# Only proceed if we have content
if ($contentLines.Count -gt 0) {
    # Build GitHub Action URL
    $actionUrl = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    
    # Build full content
    $fullContent = "GitHub Action: $actionUrl`n" + ($contentLines -join "`n")
    
    # Build Discord post payload
    $discordPost = @{
        "username" = "7th Heaven Catalog"
        "avatar_url" = "https://github.com/tsunamods-codes/7th-Heaven/raw/master/.logo/app.png"
        "content" = $fullContent
        "flags" = 4
    } | ConvertTo-Json -Depth 10
    
    # Send to Discord
    Invoke-RestMethod -Uri $env:_MAP_7TH_INTERNAL -ContentType "application/json" -Method Post -Body $discordPost
}
