Set-StrictMode -Version Latest

if ($env:_BUILD_BRANCH -eq "refs/heads/master" -Or $env:_BUILD_BRANCH -eq "refs/tags/canary") {
  $env:_IS_BUILD_CANARY = "true"
  $env:_IS_GITHUB_RELEASE = "true"
}
elseif ($env:_BUILD_BRANCH -like "refs/tags/*") {
  $env:_BUILD_VERSION = $env:_BUILD_VERSION.Substring(0, $env:_BUILD_VERSION.LastIndexOf('.')) + ".0"
  $env:_IS_GITHUB_RELEASE = "true"
}
$env:_RELEASE_VERSION = "v${env:_BUILD_VERSION}"

Write-Output "--------------------------------------------------"
Write-Output "RELEASE VERSION: $env:_RELEASE_VERSION"
Write-Output "--------------------------------------------------"

Write-Output "_BUILD_VERSION=${env:_BUILD_VERSION}" >> ${env:GITHUB_ENV}
Write-Output "_RELEASE_VERSION=${env:_RELEASE_VERSION}" >> ${env:GITHUB_ENV}
Write-Output "_IS_BUILD_CANARY=${env:_IS_BUILD_CANARY}" >> ${env:GITHUB_ENV}
Write-Output "_IS_GITHUB_RELEASE=${env:_IS_GITHUB_RELEASE}" >> ${env:GITHUB_ENV}

# Combine XML files: one catalog per subfolder under mods/
# Each subfolder (mods/qhimm, mods/sega, ...) is merged into catalogs/<name>.xml
$catalogNames = @{
    qhimm = "Qhimm Catalog"
    sega  = "Sega Catalog"
}

$catalogSubfolders = Get-ChildItem -Path "mods" -Directory
$generatedCatalogs = @()

# Set-Content/Add-Content do not create missing parent folders, so make sure
# the catalogs/ output folder exists before writing into it.
if (-not (Test-Path -Path "catalogs")) {
    New-Item -ItemType Directory -Path "catalogs" | Out-Null
}

foreach ($dir in $catalogSubfolders) {
    $catalogKey = $dir.Name
    if ($catalogNames.ContainsKey($catalogKey)) {
        $catalogName = $catalogNames[$catalogKey]
    }
    else {
        $catalogName = "$catalogKey Catalog"
    }

    $finalXml = Join-Path "catalogs" "$catalogKey.xml"
    Write-Output "Building catalog: $finalXml"

    Set-Content -Path $finalXml -Value '<?xml version="1.0"?>'
    Add-Content -Path $finalXml -Value ('<Catalog Name="' + $catalogName + '" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">')
    Add-Content -Path $finalXml -Value '<Mods>'

    # Loop over the mod.xml files inside this catalog's folder
    $files = Get-ChildItem -Path $dir.FullName -Recurse -Filter *.xml
    foreach ($file in $files) {
        # Read the mod.xml
        $xml = Get-Content -LiteralPath $file.FullName -Raw

        # Remove the initial xml tag
        $xml = $xml.Replace('<?xml version="1.0"?>', '')

        # Add content to final xml
        Add-Content -Path $finalXml -Value $xml
    }

    Add-Content -Path $finalXml -Value '</Mods>'
    Add-Content -Path $finalXml -Value '</Catalog>'

    $generatedCatalogs += , $finalXml
}

# GitHub Actions checks out 7th-Heaven into app before running this script.
# Clone it on local runs when that checkout is not already present.
if (-not (Test-Path -Path "app/CatalogValidator")) {
    if (Test-Path -Path "app") {
        throw "The app directory exists but does not contain CatalogValidator."
    }

    git clone "https://github.com/tsunamods-codes/7th-Heaven.git" "app"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone 7th-Heaven into the app directory."
    }
}

# Build dotnet run arguments
$dotnetArgs = @('run', '--property', 'WarningLevel=0;NuGetAudit=false', '--project', 'app/CatalogValidator')

# Validate every generated catalog
$exitCode = 0
foreach ($finalXml in $generatedCatalogs) {
    $appArgs = @($finalXml)
    if ($env:_VALIDATE_LINKS -eq 'true') {
        $appArgs += '--validate-links'
    }

    & dotnet @dotnetArgs -- @appArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Catalog validation failed for: $finalXml"
        $exitCode = $LASTEXITCODE
    }
}

if ($exitCode -ne 0) {
    exit $exitCode
}
