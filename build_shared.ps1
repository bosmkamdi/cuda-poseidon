# Build CUDA Poseidon as a shared library (DLL on Windows)
# Multi-curve support via -Field parameter
# Usage:
#   .\build_shared.ps1                  # Default BN254
#   .\build_shared.ps1 -Field BLS12_381 # BLS12-381 field
#   .\build_shared.ps1 -Field VESTA     # Vesta field
#   .\build_shared.ps1 -Field PALLAS    # Pallas field

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
Write-Output "Building shared library for field: $Field ($flag)"

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

$nvcc     = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3\bin\nvcc.exe"
$cu_file  = Join-Path $PSScriptRoot "poseidon_cuda.cu"
$obj_file = Join-Path $PSScriptRoot "poseidon_cuda.obj"
$def_file = Join-Path $PSScriptRoot "poseidon_cuda.def"
$dll_file = Join-Path $PSScriptRoot "poseidon_cuda.dll"
$lib_file = Join-Path $PSScriptRoot "poseidon_cuda.lib"

# Create .def file for explicit exports
@'
LIBRARY poseidon_cuda
EXPORTS
    poseidon_init
    poseidon_cleanup
    poseidon_hash_batch
    merkle_build_gpu
    poseidon_get_device
    poseidon_get_field_name
    poseidon_get_default_rounds
'@ | Set-Content -Path $def_file -Encoding ASCII

Write-Output "Compiling CUDA object (device code, field=$Field)..."
& $nvcc -O3 -DPOSEIDON_EXPORTS "$flag" -arch=sm_89 -dc -c -o $obj_file $cu_file

if ($LASTEXITCODE -ne 0) {
    Write-Error "nvcc compilation failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Output "Linking DLL with nvcc..."
& $nvcc -shared -o $dll_file $obj_file

if ($LASTEXITCODE -eq 0) {
    Write-Output "BUILD SUCCESS: $dll_file ($Field)"
} else {
    Write-Error "LINK FAILED with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
