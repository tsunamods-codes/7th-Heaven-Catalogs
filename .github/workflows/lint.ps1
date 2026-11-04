Set-StrictMode -Version Latest

$headers = @{
  Accept = "application/vnd.github+json"
  Authorization = "Bearer $env:GITHUB_TOKEN"
  "X-GitHub-Api-Version" = "2022-11-28"
}

$page = 1
$xmlFiles = @()
do {
  $uri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/pulls/$env:PR_NUMBER/files?per_page=100&page=$page"
  $files = @(Invoke-RestMethod -Uri $uri -Headers $headers)
  $xmlFiles += @($files | Where-Object {
    $_.status -ne "removed" -and $_.filename -match '(?i)\.xml$'
  })
  $hasMore = $files.Count -eq 100
  $page++
} while ($hasMore)

if ($xmlFiles.Count -eq 0) {
  Write-Output "No non-deleted XML files touched by this pull request."
  exit 0
}

$failures = @()
foreach ($file in $xmlFiles) {
  $path = $file.filename.Replace("/", "\")
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "XML file touched by the pull request was not found in the checkout: $($file.filename)"
  }

  Write-Output "Linting changed XML file: $($file.filename)"
  & xmllint --noout $path
  if ($LASTEXITCODE -ne 0) {
    $failures += $file.filename
  }
}

if ($failures.Count -gt 0) {
  throw "xmllint failed for: $($failures -join ', ')"
}
