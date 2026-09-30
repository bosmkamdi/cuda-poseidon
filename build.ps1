# Build script for CUDA Poseidon library
# Usage: .\build.ps1

$ErrorActionPreference = "Stop"

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
$cu_file = Join-Path $PSScriptRoot "poseidon_cuda.cu"
$c_file  = Join-Path $PSScriptRoot "test_poseidon.c"
$out_exe = Join-Path $PSScriptRoot "test_poseidon.exe"

Write-Output "Compiling..."
& $nvcc -O3 -arch=sm_89 -o $out_exe $cu_file $c_file

if ($LASTEXITCODE -eq 0) {
    Write-Output "BUILD SUCCESS: $out_exe"
} else {
    Write-Error "BUILD FAILED with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
