# Build CUDA Poseidon as a shared library (DLL on Windows)
# Usage: .\build_shared.ps1

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
'@ | Set-Content -Path $def_file -Encoding ASCII

Write-Output "Compiling CUDA object (device code)..."
& $nvcc -O3 -arch=sm_89 -dc -DPOSEIDON_EXPORTS -c -o $obj_file $cu_file

if ($LASTEXITCODE -ne 0) {
    Write-Error "nvcc compilation failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Output "Linking DLL with nvcc..."
# nvcc understands how to link device code with CUDA runtime
& $nvcc -shared -o $dll_file $obj_file

if ($LASTEXITCODE -eq 0) {
    Write-Output "BUILD SUCCESS: $dll_file"
} else {
    Write-Error "LINK FAILED with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
