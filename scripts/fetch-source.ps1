[CmdletBinding()]
param(
    [string]$RepositoryUrl = 'https://github.com/rustdesk/rustdesk-server.git',
    [string]$BaseCommit = '73523b31cfd25d77dee862e6fc9f5e1fb5e485ef',
    [string]$SourceDir = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot '..'))
if (-not $SourceDir) {
    $SourceDir = Join-Path $BuildRoot 'work\source'
}
$ExpectedCommon = '83419b6549636ee39dacef7776c473f5802e08d6'
$ExpectedLockHash = 'F5E17E33F48875A3A63C14002A6D94278AC6A02381C2E4C1934900823BC31528'

function Resolve-UnderBuildRoot {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    $root = $BuildRoot.TrimEnd('\') + '\'
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside build root: $full"
    }
    return $full
}

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments, [string]$WorkingDirectory = (Get-Location).Path)
    Write-Host "+ $File $($Arguments -join ' ')"
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

$SourceDir = Resolve-UnderBuildRoot $SourceDir
$workDir = Resolve-UnderBuildRoot (Join-Path $BuildRoot 'work')
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

if (Test-Path -LiteralPath $SourceDir) {
    Remove-Item -LiteralPath $SourceDir -Recurse -Force
}

Invoke-Checked git @('clone', '--recursive', $RepositoryUrl, $SourceDir)
Invoke-Checked git @('-C', $SourceDir, 'checkout', '--detach', $BaseCommit)
Invoke-Checked git @('-C', $SourceDir, 'submodule', 'update', '--init', '--recursive')

$actual = (& git -C $SourceDir rev-parse HEAD).Trim()
if ($actual -ne $BaseCommit) {
    throw "Unexpected source commit: $actual"
}

$submodule = (& git -C $SourceDir ls-files -s libs/hbb_common).Trim().Split(' ')[1]
if ($submodule -ne $ExpectedCommon) {
    throw "Unexpected hbb_common commit: $submodule"
}

$lockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $SourceDir 'Cargo.lock')).Hash
if ($lockHash -ne $ExpectedLockHash) {
    throw "Unexpected Cargo.lock SHA-256: $lockHash"
}

Write-Host "Fetched pinned RustDesk Server source at $BaseCommit"
