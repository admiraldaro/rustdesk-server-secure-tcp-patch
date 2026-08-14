[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$PatchFile = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ExpectedBase = '73523b31cfd25d77dee862e6fc9f5e1fb5e485ef'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SourceDir) {
    $SourceDir = Join-Path $ScriptRoot '..\work\source'
}
if (-not $PatchFile) {
    $PatchFile = Join-Path $ScriptRoot '..\patches\secure-tcp-keyexchange.patch'
}
$SourceDir = [System.IO.Path]::GetFullPath($SourceDir)
$PatchFile = [System.IO.Path]::GetFullPath($PatchFile)

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    Write-Host "+ $File $($Arguments -join ' ')"
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

$head = (& git -C $SourceDir rev-parse HEAD).Trim()
if ($head -ne $ExpectedBase) {
    throw "Expected clean base commit $ExpectedBase, got $head"
}

Invoke-Checked git @('-C', $SourceDir, 'apply', '--check', $PatchFile)
Invoke-Checked git @('-C', $SourceDir, 'apply', $PatchFile)
Invoke-Checked git @('-C', $SourceDir, 'diff', '--check')

$changed = @(& git -C $SourceDir diff --name-only)
$unexpected = @($changed | Where-Object { $_ -ne 'src/rendezvous_server.rs' })
if ($unexpected.Count -gt 0) {
    throw "Patch changed unexpected files: $($unexpected -join ', ')"
}

Write-Host "Applied secure TCP KeyExchange patch."
