[CmdletBinding()]
param(
    [string]$Binary = '',
    [string]$Output = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Binary) {
    $Binary = Join-Path $ScriptRoot '..\dist\hbbs'
}
if (-not $Output) {
    $Output = Join-Path $ScriptRoot '..\dist\hbbs.verify.txt'
}
$Binary = [System.IO.Path]::GetFullPath($Binary)
$Output = [System.IO.Path]::GetFullPath($Output)
$outDir = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Find-Tool {
    param([string]$Name, [string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Add-Line {
    param([System.Collections.Generic.List[string]]$Lines, [string]$Text = '')
    [void]$Lines.Add($Text)
}

function Add-Command {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [string]$File,
        [string[]]$Arguments
    )
    Add-Line $Lines "## $Title"
    if (-not $File) {
        Add-Line $Lines "tool unavailable"
        Add-Line $Lines
        return
    }
    Add-Line $Lines "+ $File $($Arguments -join ' ')"
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $captured = & $File @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    if ($captured) {
        foreach ($line in $captured) {
            Add-Line $Lines ($line.ToString())
        }
    }
    Add-Line $Lines "exit_code=$exitCode"
    Add-Line $Lines
}

$fileTool = Find-Tool 'file.exe' @('C:\msys64\usr\bin\file.exe', 'C:\msys64\ucrt64\bin\file.exe')
$readelf = Find-Tool 'readelf.exe' @('C:\msys64\ucrt64\bin\readelf.exe', 'C:\msys64\usr\bin\readelf.exe')
$objdump = Find-Tool 'objdump.exe' @('C:\msys64\ucrt64\bin\objdump.exe', 'C:\msys64\usr\bin\objdump.exe')
$strings = Find-Tool 'strings.exe' @('C:\msys64\ucrt64\bin\strings.exe', 'C:\msys64\usr\bin\strings.exe')
$ldd = Find-Tool 'ldd.exe' @('C:\msys64\usr\bin\ldd.exe', 'C:\msys64\ucrt64\bin\ldd.exe')

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines "hbbs binary verification"
Add-Line $lines "generated_at=$(Get-Date -Format o)"
Add-Line $lines "binary=$Binary"
Add-Line $lines

$item = Get-Item -LiteralPath $Binary
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $Binary
Add-Line $lines "## stat"
Add-Line $lines "length=$($item.Length)"
Add-Line $lines "last_write_time=$($item.LastWriteTime.ToString('o'))"
Add-Line $lines "mode=$($item.Mode)"
Add-Line $lines
Add-Line $lines "## sha256sum"
Add-Line $lines "$($hash.Hash.ToLowerInvariant())  hbbs"
Add-Line $lines

Add-Command $lines 'file' $fileTool @($Binary)
Add-Command $lines 'readelf -h' $readelf @('-h', $Binary)
Add-Command $lines 'readelf -l' $readelf @('-l', $Binary)
Add-Command $lines 'readelf -d' $readelf @('-d', $Binary)
Add-Command $lines 'readelf -A' $readelf @('-A', $Binary)
Add-Command $lines 'readelf -V' $readelf @('-V', $Binary)
Add-Command $lines 'objdump -f' $objdump @('-f', $Binary)
Add-Command $lines 'ldd' $ldd @($Binary)

Add-Line $lines "## selected strings"
if ($strings) {
    $patterns = @(
        'RustDesk ID/Rendezvous Server',
        '1.1.16',
        'KeyExchange phase 1',
        'Ignoring KeyExchange',
        'Decryption error',
        'connection secured',
        'expected 2 keys',
        'malformed key sizes',
        'no exchange in progress',
        'failed to open sealed key'
    )
    $stringOutput = & $strings $Binary 2>&1
    foreach ($pattern in $patterns) {
        $matches = $stringOutput | Select-String -SimpleMatch $pattern
        if ($matches) {
            Add-Line $lines "present: $pattern"
        } else {
            Add-Line $lines "missing: $pattern"
        }
    }
} else {
    Add-Line $lines "tool unavailable"
}
Add-Line $lines

Set-Content -LiteralPath $Output -Value $lines -Encoding ASCII
Write-Host "Wrote $Output"
