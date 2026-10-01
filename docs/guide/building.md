# Building from Source

## Quick Build

```bash
# Linux: shared library
nvcc -O3 --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC

# Windows: DLL
nvcc -O3 -shared -o poseidon_cuda.dll poseidon_cuda.cu

# Tests
nvcc -O3 -o test_poseidon test_poseidon.c poseidon_cuda.cu
./test_poseidon
```

## Multi-Architecture Build

The recom way to build for maximum compatibility across GPU generations:

```bash
nvcc -O3 --use_fast_math \
  -gencode arch=compute_70,code=sm_70 \
  -gencode arch=compute_75,code=sm_75 \
  -gencode arch=compute_80,code=sm_80 \
  -gencode arch=compute_86,code=sm_86 \
  -gencode arch=compute_89,code=sm_89 \
  -gencode arch=compute_90,code=sm_90 \
  --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC
```

## Build Variables

| Flag | Default | Description |
|------|---------|-------------|
| `-O3` | — | Maximum optimization level |
| `--use-fast-math` | off | Faster but potentially less precise FP math |
| `-DPOSEIDON_FIELD_BN254` | on | Use BN254 field (alt_bn128) |
| `-DPOSEIDON_FIELD_BLS12_381` | off | Use BLS12-381 scalar field |
| `-DPOSEIDON_ROUNDS` | 8 | Number of hash rounds |

### Selecting a Field

```bash
# BLS12-381 (Ethereum 2.0)
nvcc -O3 -DPOSEIDON_FIELD_BLS12_381 -o poseidon_bls.so poseidon_cuda.cu

# Default BN254
nvcc -O3 -DPOSEIDON_FIELD_BN254 -o poseidon_bn254.so poseidon_cuda.cu
```

## Build System Integration

### CMake (Recommended)

```cmake
cmake_minimum_required(VERSION 3.18)
project(myapp LANGUAGES CUDA CXX)

find_package(CUDAToolkit REQUIRED)

add_library(poseidon_cuda SHARED poseidon_cuda.cu)
target_compile_options(poseidon_cuda PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:-O3 --use-fast_math>)
set_target_properties(poseidon_cuda PROPERTIES
    CUDA_ARCHITECTURES "70;75;80;86;89;90"
)
```

### Makefile

```makefile
NVCC = nvcc
NVCCFLAGS = -O3 --use_fast_math
ARCHES = -gencode arch=compute_80,code=sm_80

all: libposeidon_cuda.so test_poseidon

libposeidon_cuda.so: poseidon_cuda.cu poseidon_cuda.h
	$(NVCC) $(NVCCFLAGS) $(ARCHES) --shared -o $@ $< -Xcompiler -fPIC
```
