<# Cargo bridge for SoundCraft.slnx (Visual Studio 2026, Windows x64).
   Cargo owns the build. Outputs are isolated in this repository's target/visual-studio. #>
[CmdletBinding()]
param(
    [ValidateSet('Build', 'Rebuild', 'Clean')]
    [string] $Action = 'Build',
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string] $Toolchain = '1.95.0-x86_64-pc-windows-msvc',
    [AllowEmptyString()]
    [string] $Features = '',
    [switch] $Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$AppName = 'soundcraft'
$WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$TargetTriple = 'x86_64-pc-windows-msvc'
$CargoProfile = if ($Configuration -eq 'Debug') { 'dev' } else { 'release' }
$OutputProfile = if ($Configuration -eq 'Debug') { 'debug' } else { 'release' }
$TargetDirectory = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot 'target\visual-studio'))
if (-not (Test-Path -LiteralPath (Join-Path $WorkspaceRoot "apps\$AppName\Cargo.toml") -PathType Leaf)) {
    throw "The build helper must remain in SoundCraft's packaging/windows directory."
}
$WorkspacePrefix = $WorkspaceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $TargetDirectory.StartsWith($WorkspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing a Cargo output/clean path outside this repository.'
}

# Resolve Cargo even when an existing Visual Studio process has an older PATH.
$CargoHomePath = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
$CargoExecutable = Join-Path $CargoHomePath 'bin\cargo.exe'
if (-not (Test-Path -LiteralPath $CargoExecutable -PathType Leaf)) {
    $CargoCommand = Get-Command cargo.exe -ErrorAction SilentlyContinue
    if ($null -eq $CargoCommand) { throw 'Cargo is missing. Install Rust with rustup; see docs/visual-studio.md.' }
    $CargoExecutable = $CargoCommand.Source
}
$SavedEnvironment = @{}
foreach ($VariableName in @('PATH', 'CARGO_TARGET_DIR', 'CARGO_TERM_COLOR', 'CARGO_PROFILE_DEV_DEBUG', 'CARGO_PROFILE_DEV_STRIP')) {
    $SavedEnvironment[$VariableName] = [Environment]::GetEnvironmentVariable($VariableName, 'Process')
}
function Invoke-AppCargo([string[]] $Arguments) {
    & $CargoExecutable "+$Toolchain" @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Cargo $($Arguments[0]) failed with exit code $LASTEXITCODE." }
}

Push-Location -LiteralPath $WorkspaceRoot
try {
    $env:PATH = "$(Split-Path -Parent $CargoExecutable);$env:PATH"
    $env:CARGO_TARGET_DIR = $TargetDirectory
    $env:CARGO_TERM_COLOR = 'never'
    if ($Configuration -eq 'Debug') {
        # Preserve upstream optimization and package overrides, while enabling full
        # symbols for workspace code. Some upstream profiles only keep line tables.
        $env:CARGO_PROFILE_DEV_DEBUG = '2'
        $env:CARGO_PROFILE_DEV_STRIP = 'none'
    }
    Write-Output "SoundCraft $Configuration ($TargetTriple; Rust $Toolchain)"
    if ($Action -in @('Clean', 'Rebuild')) {
        # Clean only this desktop package/profile in the validated VS target directory.
        Invoke-AppCargo -Arguments @('clean', '--package', $AppName, '--target', $TargetTriple, '--profile', $CargoProfile, '--target-dir', $TargetDirectory)
    }
    if ($Action -ne 'Clean') {
        $BuildArguments = @('build', '--locked', '--package', $AppName, '--bin', $AppName, '--target', $TargetTriple, '--profile', $CargoProfile, '--target-dir', $TargetDirectory, '--message-format', 'short')
        if ($Features) { $BuildArguments += @('--features', $Features) }
        if ($Offline) { $BuildArguments += '--offline' }
        Invoke-AppCargo -Arguments $BuildArguments
        $OutputDirectory = Join-Path (Join-Path $TargetDirectory $TargetTriple) $OutputProfile
        if (-not (Test-Path -LiteralPath (Join-Path $OutputDirectory "$AppName.exe") -PathType Leaf)) {
            throw 'Cargo succeeded but the expected desktop executable is missing.'
        }
        if ($Configuration -eq 'Debug' -and -not (Test-Path -LiteralPath (Join-Path $OutputDirectory "$AppName.pdb") -PathType Leaf)) {
            throw 'Debug build did not produce the expected PDB. Check external Rust flags/profile overrides.'
        }
    }
} finally {
    Pop-Location
    foreach ($VariableName in $SavedEnvironment.Keys) {
        if ($null -eq $SavedEnvironment[$VariableName]) {
            Remove-Item -LiteralPath "Env:$VariableName" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($VariableName, $SavedEnvironment[$VariableName], 'Process')
        }
    }
}
