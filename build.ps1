# Build script for CUDA Poseidon — multi-curve support
# Usage:
#   .\build.ps1                  # Build tests (default BN254)
#   .\build.ps1 -Field BLS12_381 # Build for BLS12-381 field
#   .\build.ps1 -Field VESTA    # Build for Vesta field
#   .\build.rs1 -Field PALLAS   # Build for Pallas field

param(
    [ValidateSet("BN254", "BLS12_381", "VESTA", "PALLAS")]
    [string]$Field = "BN254"
)

$ErrorActionPreference = "Stop"

$fieldFlags = @{
    "BN254"      = "-DPOSEIDON_FIELD_BN254"
    "BLS12_381"  = "-DPOSEIDON_FIELD_BLS12_381"
    "VESTA"      = "-DPOSEIDON_FIELD_VESTA"
    "PALLAS"     = "-DPOSEIDON_FIELD_PALLAS"
}

$flag = $fieldFlags[$Field]
Write-Output "Building for field: $Field ($flag)"

# Setup MSVC environment
$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
    Write-Error "vcvars64.bat not found at: $vcvars"
    exit 1
}

Write-Output "Setting up MSVC environment..."
cmd /c "`"$vcvars`" && set" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

$nvcc = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3\bin\nvcc.exe"
$cu_file  = Join-Path $PSScriptRoot "poseidon_cuda.cu"
$c_file   = Join-Path $PSScriptRoot "test_poseidon.c"
$out_exe  = Join-Path $PSScriptRoot "test_poseidon.exe"

Write-Output "Compiling ($Field, sm_89)..."
& $nvcc -O3 -DPOSEIDON_EXPORTS "$flag" -arch=sm_89 -o $out_exe $cu_file $c_file

if ($LASTEXITCODE -eq 0) {
    Write-Output "BUILD SUCCESS: $out_exe ($Field)"
} else {
    Write-Error "BUILD FAILED with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
