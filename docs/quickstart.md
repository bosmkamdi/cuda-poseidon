# Quick Start

Get cuda-poseidon running on your GPU in under 5 minutes.

## Prerequisites

- NVIDIA GPU with Compute Capability 5.0+ (Volta or newer recommended)
- CUDA Toolkit 11.0+ installed
- C++17 compatible compiler
- Python 3.8+ (optional, for Python bindings)

## Install

### Option 1: Build from Source

```bash
git clone https://github.com/bosmkamdi/cuda-poseidon.git
cd cuda-poseidon

# Build the shared library
nvcc -O3 --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC
# On Windows:  nvcc -O3 -shared -o poseidon_cuda.dll poseidon_cuda.cu
```

### Option 2: Docker

```bash
docker pull ghcr.io/bosmkamdi/cuda-poseidon:latest
docker run --rm --gpus all ghcr.io/bosmkamdi/cuda-poseidon:latest
```

### Option 3: Python (pip)

```bash
pip install cuda-poseidon
```

## First Hash

### Python

```python
from poseidon_py import gpu_poseidon_hash, get_device_info, merkle_root_gpu
import random

# Check GPU
name, vram = get_device_info()
print(f"GPU: {name} ({vram} MB)")

# Hash a pair
pairs = [(123456, 789012)]
digest = gpu_poseidon_hash(pairs)
print(f"Hash: 0x{digest[0][0]:08x} 0x{digest[0][1]:08x}")

# Batch hash 100K pairs
pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(100_000)]
digests = gpu_poseidon_hash(pairs)

# Merkle root
leaves = pairs[:65536]
root = merkle_root_gpu(leaves)
print(f"Root: 0x{root[0]:08x}")
```

### C/C++

```c
#include "poseidon_cuda.h"
#include <stdio.h>

int main() {
    poseidon_init();

    // Single hash: input pair (123456, 789012)
    uint32_t input[2]  = {123456, 789012};
    uint32_t output[2] = {0};

    poseidon_hash_batch(input, output, 1, 8);
    printf("Hash: 0x%08x 0x%08x\n", output[0], output[1]);

    poseidon_cleanup();
    return 0;
}
```

```bash
# Compile and run
gcc -o myapp myapp.c -L. -I. -lposeidon_cuda
LD_LIBRARY_PATH=. ./myapp
```

## Run Benchmarks

```bash
cd bench
python3 bench.py --output ../benchmark_results.md
```

## Next Steps

- [Installation Guide](guide/installation.md) — detailed setup instructions
- [Building](guide/building.md) — compile options, multi-arch targets
- [API Reference](api/c-api.md) — complete C/C++ and Python API docs
- [Multi-Curve Support](advanced/multi-curve.md) — BN254, BLS12-381 fields
