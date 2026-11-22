[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $PSBoundParameters.ContainsKey('Path')) {
    $Path = Join-Path $repositoryRoot 'mods'
}

$xmlRules = @{}
$inXmlSection = $false
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $repositoryRoot '.editorconfig'))) {
    $line = $line.Trim()
    if ($line -eq '' -or $line.StartsWith('#') -or $line.StartsWith(';')) {
        continue
    }
    if ($line.StartsWith('[')) {
        $inXmlSection = $line -eq '[*.xml]'
        continue
    }
    if ($inXmlSection) {
        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) {
            throw "Invalid XML setting in .editorconfig: $line"
        }
        $xmlRules[$parts[0].Trim().ToLowerInvariant()] = $parts[1].Trim().ToLowerInvariant()
    }
}
foreach ($key in @('charset', 'indent_style', 'indent_size', 'end_of_line', 'insert_final_newline', 'trim_trailing_whitespace')) {
    if (-not $xmlRules.ContainsKey($key)) {
        throw "Missing '$key' in the root .editorconfig [*.xml] section."
    }
}
$indentSize = 0
if (-not [int]::TryParse($xmlRules.indent_size, [ref]$indentSize) -or $indentSize -lt 1) {
    throw "The XML indent_size in .editorconfig must be a positive integer."
}
if ($xmlRules.indent_style -notin @('space', 'tab') -or
    $xmlRules.charset -notin @('utf-8', 'utf-8-bom') -or
    $xmlRules.end_of_line -notin @('lf', 'crlf', 'cr') -or
    $xmlRules.insert_final_newline -notin @('true', 'false')) {
    throw "Unsupported XML formatting settings in .editorconfig."
}
if ($xmlRules.trim_trailing_whitespace -ne 'false') {
    throw "XML trim_trailing_whitespace must be false to preserve text values."
}

function Write-FormattedNode {
    param(
        [System.Xml.XmlNode]$Node,
        [System.Xml.XmlWriter]$Writer,
        [bool]$PreserveSpace = $false
    )

    if ($Node -isnot [System.Xml.XmlElement]) {
        $Node.WriteTo($Writer)
        return
    }

    switch ($Node.GetAttribute('space', 'http://www.w3.org/XML/1998/namespace')) {
        'preserve' { $PreserveSpace = $true }
        'default' { $PreserveSpace = $false }
    }
    $hasElementChildren = @($Node.ChildNodes | Where-Object {
        $_ -is [System.Xml.XmlElement]
    }).Count -gt 0
    $mixedContent = @($Node.ChildNodes | Where-Object {
        $_.NodeType -in @(
            [System.Xml.XmlNodeType]::Text,
            [System.Xml.XmlNodeType]::CDATA,
            [System.Xml.XmlNodeType]::SignificantWhitespace
        ) -or ($_ -is [System.Xml.XmlWhitespace] -and -not $hasElementChildren)
    }).Count -gt 0

    $Writer.WriteStartElement($Node.Prefix, $Node.LocalName, $Node.NamespaceURI)
    foreach ($attribute in $Node.Attributes) {
        $attribute.WriteTo($Writer)
    }
    if ($mixedContent -or $PreserveSpace) {
        # Mark mixed content before the first child so indentation cannot add text.
        $Writer.WriteString('')
    }
    foreach ($child in $Node.ChildNodes) {
        if ($child -is [System.Xml.XmlWhitespace] -and -not $mixedContent -and -not $PreserveSpace) {
            continue
        }
        Write-FormattedNode -Node $child -Writer $Writer -PreserveSpace $PreserveSpace
    }
    if ($Node.IsEmpty) {
        $Writer.WriteEndElement()
    }
    else {
        $Writer.WriteFullEndElement()
    }
}

$item = Get-Item -LiteralPath $Path
$files = if ($item.PSIsContainer) {
    @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Filter '*.xml' | Sort-Object FullName)
}
else {
    @($item)
}
if (@($files).Count -eq 0) {
    throw "No XML files found in: $Path"
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding(($xmlRules.charset -eq 'utf-8-bom'))
$settings.Indent = $true
$settings.IndentChars = if ($xmlRules.indent_style -eq 'tab') { "`t" } else { ' ' * $indentSize }
$settings.NewLineChars = switch ($xmlRules.end_of_line) {
    'lf' { "`n" }
    'crlf' { "`r`n" }
    'cr' { "`r" }
}
$settings.NewLineHandling = [System.Xml.NewLineHandling]::Entitize

$changed = 0
$failed = $false
foreach ($file in $files) {
    try {
        $original = [System.IO.File]::ReadAllBytes($file.FullName)
        $inputStream = New-Object System.IO.MemoryStream(,$original)
        $reader = $null
        try {
            $reader = New-Object System.Xml.XmlTextReader($inputStream)
            $reader.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
            $reader.XmlResolver = $null
            $reader.Normalization = $false
            $document = New-Object System.Xml.XmlDocument
            $document.PreserveWhitespace = $true
            $document.XmlResolver = $null
            $document.Load($reader)
        }
        finally {
            if ($null -ne $reader) { $reader.Dispose() }
            $inputStream.Dispose()
        }

        $outputStream = New-Object System.IO.MemoryStream
        $writer = $null
        try {
            $settings.OmitXmlDeclaration = $null -eq $document.FirstChild -or
                $document.FirstChild.NodeType -ne [System.Xml.XmlNodeType]::XmlDeclaration
            $writer = [System.Xml.XmlWriter]::Create($outputStream, $settings)
            foreach ($node in $document.ChildNodes) {
                if ($node -isnot [System.Xml.XmlWhitespace]) {
                    Write-FormattedNode -Node $node -Writer $writer
                }
            }
            $writer.Flush()
            if ($xmlRules.insert_final_newline -eq 'true') {
                $newline = $settings.Encoding.GetBytes($settings.NewLineChars)
                $outputStream.Write($newline, 0, $newline.Length)
            }
            $formatted = $outputStream.ToArray()
        }
        finally {
            if ($null -ne $writer) { $writer.Dispose() }
            $outputStream.Dispose()
        }

        if ([Convert]::ToBase64String($original) -ne [Convert]::ToBase64String($formatted)) {
            $changed++
            if ($Check) {
                Write-Output "Needs formatting: $($file.FullName)"
            }
            else {
                [System.IO.File]::WriteAllBytes($file.FullName, $formatted)
                Write-Output "Formatted: $($file.FullName)"
            }
        }
    }
    catch {
        Write-Error "Could not format '$($file.FullName)': $($_.Exception.Message)" -ErrorAction Continue
        $failed = $true
    }
}

Write-Output "Checked $(@($files).Count) XML file(s); $changed needed formatting."
if ($failed -or ($Check -and $changed -gt 0)) {
    exit 1
}
exit 0
