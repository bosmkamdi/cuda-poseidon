# 🔱 cuda-poseidon

**High-performance GPU-accelerated Poseidon hash implementation in CUDA C++**

<div class="grid cards" markdown>

- :rocket: __GPU Acceleration__

    ---

    Massive speedup over CPU implementations using NVIDIA CUDA cores

- :zap: __High Throughput__

    ---

    Process millions of hash operations in parallel

- :wrench: __Easy Integration__

    ---

    Simple C API and Python bindings (ctypes)

- :chart_with_upwards_trend: __Battle-Tested__

    ---

    Comprehensive test suite, CI/CD pipelines, Docker images

- :package: __Lightweight__

    ---

    Minimal dependencies, single shared library file

- :shield: __Cryptographically Secure__

    ---

    Implements full Poseidon specification

</div>

---

## Why Poseidon?

Poseidon is optimized for arithmetic circuits, making it ideal for:

- **ZK-Proof systems** (zk-SNARKs, PLONK, STARKs)
- **Blockchain applications** (Merkle trees, transaction hashing)
- **Privacy-preserving computation**
- **Cryptographic signature schemes**

## Quick Example

=== "C/C++"

    ```c
    #include "poseidon_cuda.h"
    #include <stdio.h>

    int main() {
        // Initialize GPU
        poseidon_init();

        // Input: 100,000 pairs of field elements
        uint32_t input[200000];
        uint32_t output[200000];
        // ... fill input ...

        // Batch hash on GPU
        poseidon_hash_batch(input, output, 100000, 8);

        return 0;
    }
    ```

=== "Python"

    ```python
    from poseidon_py import gpu_poseidon_hash, merkle_root_gpu
    import random

    # Batch hash on GPU
    pairs = [(random.getrandbits(30), random.getrandbits(30))
             for _ in range(100_000)]
    digests = gpu_poseidon_hash(pairs)

    # Build Merkle tree
    root = merkle_root_gpu(pairs[:65536])
    print(f"Merkle root: 0x{root[0]:08x}")
    ```

---

## Throughput Benchmarks

| Operation | Batch Size | Hashes/sec | µs/hash |
|----------:|-----------:|-----------:|-------:|
| Poseidon Hash | 1,000 | ~2,500,000 | ~0.40 |
| Poseidon Hash | 10,000 | ~8,000,000 | ~0.13 |
| Poseidon Hash | 100,000 | ~15,000,000 | ~0.07 |
| Merkle Build | 1,024 leaves | ~120,000 | — |
| Merkle Build | 16,384 leaves | ~800,000 | — |

*Benchmarks measured on NVIDIA RTX 4090. See [Benchmarks](guide/benchmarks.md) for detailed methodology.*

---

## Project Status

- ✅ CUDA kernel with optimized x⁷ S-box
- ✅ Batch hash and Merkle tree APIs
- ✅ Python bindings (ctypes)
- ✅ Comprehensive CI/CD (build, test, lint)
- ✅ Multi-architecture GPU support (sm_70 – sm_90)
- ✅ Automated benchmark suite
- ✅ Docker image (runtime + Python)
- ⭐ **Multi-curve support** (BN254, BLS12-381) — in progress
