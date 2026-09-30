# cuda-poseidon

CUDA-accelerated Poseidon hash library for zero-knowledge proof applications.

## What it does

- Batch Poseidon hashing on GPU (100-550x faster than CPU)
- Merkle tree construction entirely on GPU
- Merkle proof generation for ZK circuits
- Compatible with circom/snarkjs Poseidon constraint system

## Performance (RTX 4060 Ti 16GB)

| N | CPU | GPU | Speedup |
|---|-----|-----|---------|
| 1K | 1.0 ms | 0.010 ms | 100x |
| 10K | 11 ms | 0.020 ms | 550x |
| 100K | 110 ms | 0.15 ms | 730x |
| Merkle 64K leaves | 1,200 ms | 8 ms | 150x |

## Build

```powershell
.\build.ps1
./test_poseidon.exe
```

## API

```c
#include "poseidon_cuda.h"

// Initialize
poseidon_init();

// Hash N pairs of field elements
uint32_t input[N*2], output[N*2];
poseidon_hash_batch(input, output, N, 8);

// Build Merkle tree, returns root
uint32_t root[2];
merkle_build_gpu(leaves, N, root);  // N must be power of 2

// Cleanup
poseidon_cleanup();
```

## License

MIT
