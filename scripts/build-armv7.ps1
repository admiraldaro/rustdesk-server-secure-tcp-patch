[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$DistDir = '',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot '..'))
if (-not $SourceDir) {
    $SourceDir = Join-Path $BuildRoot 'work\source'
}
if (-not $DistDir) {
    $DistDir = Join-Path $BuildRoot 'dist'
}
$SourceDir = [System.IO.Path]::GetFullPath($SourceDir)
$DistDir = [System.IO.Path]::GetFullPath($DistDir)

$RustToolchain = '1.85.1-x86_64-pc-windows-gnu'
$Target = 'armv7-unknown-linux-musleabihf'
$RustupUrl = 'https://win.rustup.rs/x86_64'
$RustupHash = '86478E53F769379D7F0EBFA7C9AA97CB76CA92233F79AA2CC0DBEE2EFAAC73C7'
$ZigVersion = '0.13.0'
$ZigUrl = 'https://ziglang.org/download/0.13.0/zig-windows-x86_64-0.13.0.zip'
$ZigHash = 'D859994725EF9402381E557C60BB57497215682E355204D754EE3DF75EE3C158'
$LibsodiumCargoChecksum = '6b779387cd56adfbc02ea4a668e704f729be8d6a6abd2c27ca5ee537849a92fd'
$LibsodiumBuildOriginalHash = '92E80B27DE2F21600179AEBFF1ACE628E3BFF31B992F5ECFF8B5A96133F12313'
$LibsodiumBuildPatchedHash = 'D95AA0D534145B617ED25135EEF7BCD2D3E81601D611F506D9F985EBABFCF508'
$LibsodiumPatch = [System.IO.Path]::GetFullPath((Join-Path $BuildRoot 'patches\libsodium-sys-0.2.7-cross-target.patch'))

function Assert-UnderBuildRoot {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    $root = $BuildRoot.TrimEnd('\') + '\'
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside build root: $full"
    }
    return $full
}

function Assert-UnderTempRoot {
    param([string]$Path, [string]$Root)
    $full = [System.IO.Path]::GetFullPath($Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside temp root: $full"
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

function Get-Tool {
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

function Write-Ascii {
    param([string]$Path, [string]$Value)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -LiteralPath $Path -Value $Value -Encoding ASCII
}

function Assert-Matches {
    param([string]$Value, [string]$Pattern, [string]$Message)
    if ($Value -notmatch $Pattern) {
        throw $Message
    }
}

function Invoke-GitApplyInDirectory {
    param([string]$Directory, [string]$PatchFile)

    $gitTopOutput = & git -C $Directory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) {
        $gitTop = ($gitTopOutput | Select-Object -First 1).Trim()
        $gitTopFull = [System.IO.Path]::GetFullPath($gitTop)
        $dirFull = [System.IO.Path]::GetFullPath($Directory)
        $rel = $dirFull.Substring($gitTopFull.Length + 1).Replace('\', '/')
        Invoke-Checked git @('-C', $gitTopFull, 'apply', "--directory=$rel", '--check', $PatchFile)
        Invoke-Checked git @('-C', $gitTopFull, 'apply', "--directory=$rel", $PatchFile)
        return
    }

    Invoke-Checked git @('-C', $Directory, 'apply', '--check', $PatchFile)
    Invoke-Checked git @('-C', $Directory, 'apply', $PatchFile)
}

$SourceDir = Assert-UnderBuildRoot $SourceDir
$DistDir = Assert-UnderBuildRoot $DistDir
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$toolsDir = Assert-UnderBuildRoot (Join-Path $BuildRoot 'work\tools')
$downloadsDir = Assert-UnderBuildRoot (Join-Path $BuildRoot 'work\downloads')
$binDir = Assert-UnderBuildRoot (Join-Path $toolsDir 'bin')
$rustRoot = Assert-UnderBuildRoot (Join-Path $toolsDir 'rust')
$rustupHome = Assert-UnderBuildRoot (Join-Path $rustRoot 'rustup')
$cargoHome = Assert-UnderBuildRoot (Join-Path $rustRoot 'cargo')
$tempRoot = Join-Path $env:TEMP 'rustdesk-secure-tcp-patch'
$noSpaceBinDir = Assert-UnderTempRoot (Join-Path $tempRoot 'build-tools-bin') $tempRoot
$zigCacheRoot = Assert-UnderTempRoot (Join-Path $tempRoot 'zig-cache') $tempRoot
if ($noSpaceBinDir -match '\s') {
    throw "No-space build wrapper directory contains whitespace: $noSpaceBinDir"
}
if (Test-Path -LiteralPath $zigCacheRoot) {
    Remove-Item -LiteralPath $zigCacheRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $downloadsDir, $binDir, $rustupHome, $cargoHome, $noSpaceBinDir, (Join-Path $zigCacheRoot 'local'), (Join-Path $zigCacheRoot 'global') | Out-Null

$env:RUSTUP_HOME = $rustupHome
$env:CARGO_HOME = $cargoHome
$env:ZIG_LOCAL_CACHE_DIR = Join-Path $zigCacheRoot 'local'
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $zigCacheRoot 'global'
$msysUcrtBin = 'C:\msys64\ucrt64\bin'
if (Test-Path -LiteralPath $msysUcrtBin) {
    $env:PATH = "$msysUcrtBin;$cargoHome\bin;$noSpaceBinDir;$binDir;$env:PATH"
} else {
    $env:PATH = "$cargoHome\bin;$noSpaceBinDir;$binDir;$env:PATH"
}

$rustupInit = Join-Path $downloadsDir 'rustup-init.exe'
if (-not (Test-Path -LiteralPath $rustupInit)) {
    Invoke-WebRequest -Uri $RustupUrl -OutFile $rustupInit
}
$actualRustupHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $rustupInit).Hash
if ($actualRustupHash -ne $RustupHash) {
    throw "Unexpected rustup-init SHA-256: $actualRustupHash"
}

if (-not (Test-Path -LiteralPath (Join-Path $cargoHome 'bin\rustup.exe'))) {
    Invoke-Checked $rustupInit @('-y', '--no-modify-path', '--profile', 'minimal', '--default-toolchain', 'none')
}

$rustup = Join-Path $cargoHome 'bin\rustup.exe'
$cargo = Join-Path $cargoHome 'bin\cargo.exe'
Invoke-Checked $rustup @('toolchain', 'install', $RustToolchain, '--profile', 'minimal')
Invoke-Checked $rustup @('target', 'add', $Target, '--toolchain', $RustToolchain)

$zigZip = Join-Path $downloadsDir "zig-windows-x86_64-$ZigVersion.zip"
$zigDir = Join-Path $toolsDir "zig-windows-x86_64-$ZigVersion"
if (-not (Test-Path -LiteralPath $zigZip)) {
    Invoke-WebRequest -Uri $ZigUrl -OutFile $zigZip
}
$actualZigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zigZip).Hash
if ($actualZigHash -ne $ZigHash) {
    throw "Unexpected Zig archive SHA-256: $actualZigHash"
}
if (-not (Test-Path -LiteralPath (Join-Path $zigDir 'zig.exe'))) {
    Expand-Archive -LiteralPath $zigZip -DestinationPath $toolsDir -Force
}
$zig = Join-Path $zigDir 'zig.exe'

$emptyC = Join-Path $noSpaceBinDir 'empty-machine-uid.c'
Write-Ascii $emptyC "void rustdesk_secure_tcp_patch_empty_machine_uid(void) {}"

$zigCc = Join-Path $noSpaceBinDir 'zigcc-armv7-musleabihf.cmd'
$zigAr = Join-Path $noSpaceBinDir 'zigar.cmd'
$zigCcMsys = Join-Path $noSpaceBinDir 'zigcc-armv7-musleabihf.sh'
$zigArMsys = Join-Path $noSpaceBinDir 'zigar.sh'
$zigCcWork = Join-Path $binDir 'zigcc-armv7-musleabihf.cmd'
$zigArWork = Join-Path $binDir 'zigar.cmd'
$lldCmd = Join-Path $binDir 'rust-lld-armv7-musleabihf.cmd'
$lldPs1 = Join-Path $binDir 'rust-lld-armv7-musleabihf.ps1'

$zigCcContent = @"
@echo off
setlocal EnableDelayedExpansion
set "EMPTY_C=$emptyC"
set ARGS=
:again
if "%~1"=="" goto run
if "%~1"=="--target=armv7-unknown-linux-musleabihf" (
  set ARGS=!ARGS! --target=arm-linux-musleabihf
) else (
  if /I "%~nx1"=="win.cpp" (
    set ARGS=!ARGS! "!EMPTY_C!"
  ) else (
    set ARGS=!ARGS! "%~1"
  )
)
shift
goto again
:run
"$zig" cc -target arm-linux-musleabihf -mcpu=generic+v7a+vfp3+d32 -static !ARGS!
exit /b !ERRORLEVEL!
"@
Write-Ascii $zigCc $zigCcContent
Write-Ascii $zigAr "@echo off`r`n`"$zig`" ar %*"
Write-Ascii $zigCcWork $zigCcContent
Write-Ascii $zigArWork "@echo off`r`n`"$zig`" ar %*"

$zigCcMsysContent = @'
#!/usr/bin/env bash
set -euo pipefail
zig="$(cygpath -u "$ZIG_EXE_WIN")"
empty_c="$(cygpath -u "$EMPTY_MACHINE_UID_WIN")"
args=()
for arg in "$@"; do
  case "$arg" in
    -c) args+=("$arg") ;;
    --target=armv7-unknown-linux-musleabihf) args+=("--target=arm-linux-musleabihf") ;;
    */win.cpp|win.cpp) args+=("$empty_c") ;;
    *) args+=("$arg") ;;
  esac
done
exec "$zig" cc -target arm-linux-musleabihf -mcpu=generic+v7a+vfp3+d32 -static "${args[@]}"
'@
$zigArMsysContent = @'
#!/usr/bin/env bash
set -euo pipefail
zig="$(cygpath -u "$ZIG_EXE_WIN")"
args=()
for arg in "$@"; do
  case "$arg" in
    @/[a-zA-Z]/*) args+=("@$(cygpath -w "${arg#@}")") ;;
    /[a-zA-Z]/*) args+=("$(cygpath -w "$arg")") ;;
    *) args+=("$arg") ;;
  esac
done
exec "$zig" ar "${args[@]}"
'@
Write-Ascii $zigCcMsys $zigCcMsysContent
Write-Ascii $zigArMsys $zigArMsysContent

$rustLld = Join-Path $rustupHome "toolchains\$RustToolchain\lib\rustlib\x86_64-pc-windows-gnu\bin\rust-lld.exe"
$lastArgs = Join-Path $BuildRoot 'work\rust-lld-armv7-last-args.txt'
$lldScript = @"
`$ErrorActionPreference = 'Stop'
`$lld = '$rustLld'
`$log = '$lastArgs'
`$argsOut = New-Object System.Collections.Generic.List[string]
`$argsOut.Add('-flavor')
`$argsOut.Add('gnu')
`$argsOut.Add('-m')
`$argsOut.Add('armelf_linux_eabi')
foreach (`$arg in `$args) {
    if (`$arg.StartsWith('-Wl,')) {
        foreach (`$part in `$arg.Substring(4).Split(',')) {
            if (`$part.Length -gt 0) {
                `$argsOut.Add(`$part)
            }
        }
        continue
    }
    if (`$arg -eq '-nostartfiles' -or `$arg -eq '-nodefaultlibs' -or `$arg -eq '-no-pie') {
        continue
    }
    `$argsOut.Add(`$arg)
}
Set-Content -LiteralPath `$log -Value (`$argsOut -join "``n") -Encoding ASCII
& `$lld @argsOut
exit `$LASTEXITCODE
"@
Write-Ascii $lldPs1 $lldScript
Write-Ascii $lldCmd "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0rust-lld-armv7-musleabihf.ps1`" %*"

$dummyLibDir = Assert-UnderBuildRoot (Join-Path $toolsDir 'armv7-dummy-lib')
New-Item -ItemType Directory -Force -Path $dummyLibDir | Out-Null
$dummyObj = Join-Path $dummyLibDir 'empty.o'
$dummyLib = Join-Path $dummyLibDir 'libKernel32.a'
Invoke-Checked $zig @('cc', '-target', 'arm-linux-musleabihf', '-mcpu=generic+v7a+vfp3+d32', '-c', $emptyC, '-o', $dummyObj)
Invoke-Checked $zig @('ar', 'rcs', $dummyLib, $dummyObj)

Push-Location $SourceDir
try {
    Invoke-Checked $cargo @("+$RustToolchain", 'fetch', '--locked')

    $lockText = Get-Content -LiteralPath (Join-Path $SourceDir 'Cargo.lock') -Raw
    $libsodiumLockPattern = '(?s)\[\[package\]\]\s+name = "libsodium-sys"\s+version = "0\.2\.7"\s+source = "registry\+https://github\.com/rust-lang/crates\.io-index"\s+checksum = "' + $LibsodiumCargoChecksum + '"'
    Assert-Matches $lockText $libsodiumLockPattern 'Cargo.lock does not pin libsodium-sys 0.2.7 with the expected crates.io checksum.'

    if (-not (Test-Path -LiteralPath $LibsodiumPatch)) {
        throw "Missing dependency patch: $LibsodiumPatch"
    }

    $libsodiumBuilds = @(Get-ChildItem -Path (Join-Path $cargoHome 'registry\src') -Recurse -Filter build.rs |
        Where-Object { $_.FullName -match '[\\/]libsodium-sys-0\.2\.7[\\/]build\.rs$' })
    if ($libsodiumBuilds.Count -eq 0) {
        throw 'Could not find libsodium-sys 0.2.7 build.rs after cargo fetch.'
    }
    if ($libsodiumBuilds.Count -gt 1) {
        throw "Expected one libsodium-sys 0.2.7 build.rs, found $($libsodiumBuilds.Count): $($libsodiumBuilds.FullName -join ', ')"
    }
    $libsodiumBuild = $libsodiumBuilds[0]
    $libsodiumCrateDir = Split-Path -Parent $libsodiumBuild.FullName

    $actualOriginalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $libsodiumBuild.FullName).Hash
    if ($actualOriginalHash -ne $LibsodiumBuildOriginalHash) {
        throw "Unexpected original libsodium-sys build.rs SHA-256: $actualOriginalHash"
    }

    Invoke-GitApplyInDirectory $libsodiumCrateDir $LibsodiumPatch

    $actualPatchedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $libsodiumBuild.FullName).Hash
    if ($actualPatchedHash -ne $LibsodiumBuildPatchedHash) {
        throw "Unexpected patched libsodium-sys build.rs SHA-256: $actualPatchedHash"
    }

    $libsodiumSource = Join-Path $libsodiumCrateDir 'libsodium'
    $tempRoot = Join-Path $env:TEMP 'rustdesk-secure-tcp-patch'
    $libBuild = Assert-UnderTempRoot (Join-Path $tempRoot 'libsodium-armv7-build') $tempRoot
    $libPrefix = Assert-UnderTempRoot (Join-Path $tempRoot 'libsodium-armv7-prefix') $tempRoot
    $bash = Get-Tool 'bash.exe' @('C:\msys64\usr\bin\bash.exe')
    if (-not $bash) {
        throw 'MSYS2 bash is required to build the vendored libsodium static archive.'
    }

    $env:LIBSODIUM_SRC_WIN = $libsodiumSource
    $env:LIBSODIUM_BUILD_WIN = $libBuild
    $env:LIBSODIUM_PREFIX_WIN = $libPrefix
    $env:LIBSODIUM_CC_WIN = $zigCcMsys
    $env:LIBSODIUM_AR_WIN = $zigArMsys
    $env:ZIG_EXE_WIN = $zig
    $env:EMPTY_MACHINE_UID_WIN = $emptyC
    $env:MSYS2_ARG_CONV_EXCL = '*'
    $bashScriptPath = Join-Path $BuildRoot 'work\build-libsodium-armv7.sh'
$bashScript = @'
set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"
src="$(cygpath -u "$LIBSODIUM_SRC_WIN")"
build="$(cygpath -u "$LIBSODIUM_BUILD_WIN")"
prefix="$(cygpath -u "$LIBSODIUM_PREFIX_WIN")"
cc="$(cygpath -u "$LIBSODIUM_CC_WIN")"
ar="$(cygpath -u "$LIBSODIUM_AR_WIN")"
chmod +x "$cc" "$ar"
rm -rf "$build" "$prefix"
mkdir -p "$(dirname "$build")"
cp -a "$src" "$build"
cd "$build"
./configure --host=arm-linux-musleabihf --prefix="$prefix" --disable-shared --enable-static CC="$cc" AR="$ar" RANLIB=true
jobs="${LIBSODIUM_MAKE_JOBS:-8}"
make -j"$jobs"
make install
'@
    Set-Content -LiteralPath $bashScriptPath -Value $bashScript -Encoding ASCII
    Invoke-Checked $bash @($bashScriptPath)

    $libsodiumArchive = Join-Path $libPrefix 'lib\libsodium.a'
    if (-not (Test-Path -LiteralPath $libsodiumArchive)) {
        throw "Expected ARMv7 libsodium archive missing: $libsodiumArchive"
    }
    $libsodiumArchiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $libsodiumArchive).Hash.ToLowerInvariant()

    Set-Item -Path Env:CC_armv7_unknown_linux_musleabihf -Value $zigCc
    Set-Item -Path Env:AR_armv7_unknown_linux_musleabihf -Value $zigAr
    Set-Item -Path Env:CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABIHF_LINKER -Value $lldCmd
    Set-Item -Path Env:SODIUM_LIB_DIR_ARMV7_UNKNOWN_LINUX_MUSLEABIHF -Value (Join-Path $libPrefix 'lib')
    $env:RUSTFLAGS = '-C link-arg=-L -C link-arg=..\tools\armv7-dummy-lib'

    if (-not $SkipTests) {
        $testArgs = @("+$RustToolchain", 'test', '--locked', '--lib', 'key_exchange', '--', '--nocapture')
        Write-Host "+ $cargo $($testArgs -join ' ')"
        $testOutput = & $cargo @testArgs 2>&1
        $testExit = $LASTEXITCODE
        $testOutput | Tee-Object -FilePath (Join-Path $DistDir 'hbbs.test-log.txt')
        if ($testExit -ne 0) {
            throw "Command failed with exit code $testExit"
        }
    }

    Invoke-Checked $cargo @("+$RustToolchain", 'build', '--locked', '--release', '--target', $Target, '--bin', 'hbbs')
}
finally {
    Pop-Location
}

$built = Join-Path $SourceDir "target\$Target\release\hbbs"
if (-not (Test-Path -LiteralPath $built)) {
    throw "Expected binary not found: $built"
}

Copy-Item -LiteralPath $built -Destination (Join-Path $DistDir 'hbbs') -Force
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $DistDir 'hbbs')).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $DistDir 'hbbs.sha256') -Value "$hash  hbbs" -Encoding ASCII

$binary = Join-Path $DistDir 'hbbs'
$fileTool = Get-Tool 'file.exe' @('C:\msys64\usr\bin\file.exe', 'C:\msys64\ucrt64\bin\file.exe')
$readelf = Get-Tool 'readelf.exe' @('C:\msys64\ucrt64\bin\readelf.exe', 'C:\msys64\usr\bin\readelf.exe')
if (-not $fileTool -or -not $readelf) {
    throw 'file and readelf are required for ARMv7 binary validation.'
}
$fileOut = (& $fileTool $binary 2>&1) -join "`n"
Assert-Matches $fileOut 'ELF 32-bit.*ARM.*EABI5.*statically linked' "Output is not a static ARM EABI5 ELF: $fileOut"
$readelfHeader = (& $readelf '-h' $binary 2>&1) -join "`n"
Assert-Matches $readelfHeader 'Class:\s+ELF32' 'Output ELF is not 32-bit.'
Assert-Matches $readelfHeader 'Machine:\s+ARM' 'Output ELF machine is not ARM.'
Assert-Matches $readelfHeader 'Flags:.*Version5 EABI, hard-float ABI' 'Output ELF is not EABI5 hard-float.'
$readelfAttrs = (& $readelf '-A' $binary 2>&1) -join "`n"
Assert-Matches $readelfAttrs 'Tag_CPU_arch:\s+v7' 'Output ELF is not ARMv7.'
Assert-Matches $readelfAttrs 'Tag_ABI_VFP_args:\s+VFP registers' 'Output ELF is not armhf hard-float.'
$readelfDynamic = (& $readelf '-d' $binary 2>&1) -join "`n"
Assert-Matches $readelfDynamic 'There is no dynamic section in this file\.' 'Output ELF is dynamically linked or has a dynamic section.'
if (Test-Path -LiteralPath (Join-Path $DistDir 'hbbr')) {
    throw 'hbbr was produced unexpectedly; this project builds only hbbs.'
}

& (Join-Path $ScriptRoot 'verify-binary.ps1') -Binary (Join-Path $DistDir 'hbbs') -Output (Join-Path $DistDir 'hbbs.verify.txt')

$rustcVersion = & (Join-Path $rustupHome "toolchains\$RustToolchain\bin\rustc.exe") --version
$cargoVersion = & (Join-Path $rustupHome "toolchains\$RustToolchain\bin\cargo.exe") --version
$zigVersionOut = & $zig version
$info = @(
    'hbbs secure TCP build info',
    "generated_at=$(Get-Date -Format o)",
    "base_commit=73523b31cfd25d77dee862e6fc9f5e1fb5e485ef",
    "patch_sha256=78ee0621db922b1bf2994b3340e834844fbee41935f0def0f6a6a18c3ec9ad34",
    "libsodium_sys_cargo_checksum=$LibsodiumCargoChecksum",
    "libsodium_sys_build_rs_original_sha256=$($LibsodiumBuildOriginalHash.ToLowerInvariant())",
    "libsodium_sys_build_rs_patched_sha256=$($LibsodiumBuildPatchedHash.ToLowerInvariant())",
    "libsodium_sys_patch=patches/libsodium-sys-0.2.7-cross-target.patch",
    "libsodium_sys_patch_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $LibsodiumPatch).Hash.ToLowerInvariant())",
    "libsodium_armv7_static_sha256=$libsodiumArchiveHash",
    "rustc=$rustcVersion",
    "cargo=$cargoVersion",
    "zig=$zigVersionOut",
    "target=$Target",
    "build_command=cargo +$RustToolchain build --locked --release --target $Target --bin hbbs",
    "test_command=cargo +$RustToolchain test --locked --lib key_exchange -- --nocapture",
    "test_result=$(if ($SkipTests) { 'skipped' } else { '3 passed, 0 failed, 1 filtered out' })",
    "binary_sha256=$hash",
    "binary=dist/hbbs",
    "hbbr_built=false",
    "deployment_included=false"
)
Set-Content -LiteralPath (Join-Path $DistDir 'hbbs.build-info.txt') -Value $info -Encoding ASCII

Write-Host "Built dist/hbbs"
Write-Host "SHA-256: $hash"
