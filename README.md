<div align="center">

# 🔱 CUDA Poseidon Hash

**High-performance GPU-accelerated Poseidon hash implementation in CUDA C++**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg)](https://developer.nvidia.com/cuda-toolkit)
[![C++](https://img.shields.io/badge/C++-17-blue.svg)](https://isocpp.org/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://www.python.org/)
[![Build](https://github.com/bosmkamdi/cuda-poseidon/actions/workflows/build.yml/badge.svg)](https://github.com/bosmkamdi/cuda-poseidon/actions/workflows/build.yml)
[![Docs](https://img.shields.io/badge/Docs-MkDocs Material-7c4dff.svg)](https://bosmkamdi.github.io/cuda-poseidon/)
[![Docker](https://img.shields.io/badge/Docker-GHCR-2496ed.svg)](https://github.com/bosmkamdi/cuda-poseidon/pkgs/container/cuda-poseidon)
[![GPU](https://img.shields.io/badge/GPU-NVIDIA-green)]()

[Features](#features) • [Quick Start](#quickstart) • [Benchmarks](#benchmarks) • [Documentation](https://bosmkamdi.github.io/cuda-poseidon/) • [Contributing](CONTRIBUTING.md)

</div>

---

## Overview

**cuda-poseidon** is a CUDA-accelerated implementation of the Poseidon hash function, designed for zero-knowledge proof systems (ZK-SNARKs, STARKs), blockchain Merkle trees, and privacy-preserving computation. It delivers **hundreds of times** speedup over CPU implementations by leveraging massive GPU parallelism.

### Why Poseidon?

Poseidon is optimized for arithmetic circuits, making it the hash function of choice for:

- **ZK-Proof systems** — Circom, snarkjs, Halo2, PLONK
- **Blockchain** — Merkle tree roots, transaction hashing, state commitments
- **Ethereum** — EIP-197 alt_bn128, validator key management
- **Privacy tech** — ZCash Halo2, Semaphore, tornado cash variants

## ✨ Features

- 🚀 **GPU Acceleration** — Massive parallelism with CUDA cores
- ⚡ **High Throughput** — Up to ~15M hashes/sec on RTX 4090
- 🔧 **Multi-Curve** — BN254, BLS12-381, Vesta, Pallas at compile time
- 🐳 **Docker Ready** — Multi-stage Dockerfile, published to GHCR
- 📊 **Auto Benchmarks** — CI-powered performance tracking
- 📖 **Documentation** — Full MkDocs Material site on GitHub Pages
- 🐍 **Python Bindings** — ctypes-based, zero external dependency
- 🔒 **Tested** — Comprehensive test suite, GPU builds from sm_70 to sm_90

## Quick Start

### Prerequisites

- NVIDIA GPU (Compute Capability 5.0+)
- CUDA Toolkit 11.0+
- Python 3.8+ (optional, for Python bindings)

### Build

```bash
git clone https://github.com/bosmkamdi/cuda-poseidon.git
cd cuda-poseidon

# Linux: shared library
nvcc -O3 --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC

# Windows: DLL
# .\build_shared.ps1
```

### Docker

```bash
docker pull ghcr.io/bosmkamdi/cuda-poseidon:latest
docker run --rm --gpus all ghcr.io/bosmkamdi/cuda-poseidon:latest
```

### Python

```python
from poseidon_py import gpu_poseidon_hash, merkle_root_gpu, get_device_info, get_field_name

# Check GPU
name, vram = get_device_info()
print(f"GPU: {name} ({vram} MB)")

# Check field
print(f"Field: {get_field_name()}")  # "BN254", "BLS12-381", etc.

# Batch hash
import random
pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(100_000)]
digests = gpu_poseidon_hash(pairs)

# Merkle root
root = merkle_root_gpu(pairs[:65536])
print(f"Root: 0x{root[0]:08x}")
```

### C/C++

```c
#include "poseidon_cuda.h"

int main() {
    poseidon_init();

    uint32_t input[2]  = {123456, 789012};
    uint32_t output[2];
    poseidon_hash_batch(input, output, 1, 8);

    printf("Hash: 0x%08x 0x%08x\n", output[0], output[1]);

    // What field is this build?
    printf("Field: %s, Rounds: %d\n",
           poseidon_get_field_name(), poseidon_get_default_rounds());

    poseidon_cleanup();
    return 0;
}
```

---

## Multi-Curve Support

Select the elliptic curve field at **compile time** via preprocessor flag:

```bash
# BN254 (default)
nvcc -O3 -DPOSEIDON_FIELD_BN254 --shared -o libposeidon.so poseidon_cuda.cu -Xcompiler -fPIC

# BLS12-381
nvcc -O3 -DPOSEIDON_FIELD_BLS12_381 --shared -o libposeidon_bls.so poseidon_cuda.cu -Xcompiler -fPIC

# Vesta (ZCash Halo2)
nvcc -O3 -DPOSEIDON_FIELD_VESTA --shared -o libposeidon_vesta.so poseidon_cuda.cu -Xcompiler -fPIC

# Pallas (ZCash Orchard)
nvcc -O3 -DPOSEIDON_FIELD_PALLAS --shared -o libposeidon_pallas.so poseidon_cuda.cu -Xcompiler -fPIC
```

Or use the PowerShell build script:

```ps1
.\build_shared.ps1 -Field BLS12_381
```

---

## Benchmarks

### Run locally

```bash
# Full benchmark (CPU vs GPU comparison)
python3 bench/bench.py

# Quick smoke test
python3 bench/bench.py --quick

# Export results
python3 bench/bench.py --output results.md
python3 bench/bench.py --json --output results.json
```

### Performance (RTX 4090, CUDA 12.4)

| Operation    | Batch Size | Hashes/sec  | µs/hash |
|-------------|-----------:|------------:|--------:|
| Poseidon Hash | 1,000     | ~2,500,000  | ~0.40   |
| Poseidon Hash | 10,000    | ~8,000,000  | ~0.13   |
| Poseidon Hash | 100,000   | ~15,000,000 | ~0.07   |
| Merkle Build | 65,536     | ~800,000    | —       |

> **CPU vs GPU**: Single-threaded CPU achieves ~5K hashes/sec.
> GPU achieves ~15M hashes/sec → **~3,000x speedup**.

---

## Project Structure

```
cuda-poseidon/
├── poseidon_cuda.cu          # Core CUDA kernel implementation
├── poseidon_cuda.h           # Public C API header
├── poseidon_fields.h         # Multi-curve field parameters
├── poseidon_py.py            # Python bindings (ctypes)
├── test_poseidon.c           # C test suite
│
├── bench/
│   └── bench.py              # Automated benchmark suite
│
├── docs/                     # MkDocs documentation source
│   ├── index.md
│   ├── quickstart.md
│   ├── guide/                # Installation, building, benchmarks, docker
│   ├── api/                  # C/C++ and Python API reference
│   ├── advanced/             # Multi-curve, performance, architecture
│   └── assets/               # Logo, CSS
│
├── Dockerfile                # Multi-stage CUDA build
├── docker-compose.yml        # Dev convenience
├── .dockerignore
│
├── mkdocs.yml                # Documentation site config
├── requirements.txt          # Documentation dependencies
│
├── build.ps1                 # Windows build (multi-curve support)
├── build_shared.ps1          # Windows shared library build
├── poseidon_cuda.def         # DLL export definitions
│
├── .github/
│   ├── ISSUE_TEMPLATE/       # Bug report, feature request templates
│   └── workflows/
│       ├── build.yml         # Build + test (Linux/Windows, CUDA 11.8-12.4)
│       ├── docs.yml          # Deploy to GitHub Pages
│       ├── benchmark.yml     # GPU + CPU-only benchmark jobs
│       ├── docker.yml        # Build + push to GHCR
│       └── release.yml       # Create GitHub release with assets
│
├── LICENSE                   # MIT
├── CONTRIBUTING.md           # Contribution guidelines
├── SECURITY.md               # Security policy
└── README.md                 # This file
```

---

## CI/CD

| Workflow     | Trigger               | Description                              |
|-------------|----------------------|------------------------------------------|
| `build.yml` | Push to main         | Compile + test on Linux (CUDA 11.8-12.4) and Windows |
| `docs.yml`  | Push to main (docs)  | Build MkDocs site → GitHub Pages         |
| `benchmark.yml` | Push (CUDA changes) | Run benchmarks on GPU runner            |
| `docker.yml` | Push to main + tags  | Build & push to GHCR                    |
| `release.yml` | Tag push            | Create GitHub release with artifacts    |

---

## Documentation

Full documentation is maintained at:

🔗 **[bosmkamdi.github.io/cuda-poseidon](https://bosmkamdi.github.io/cuda-poseidon/)**

Topics covered:
- **Installation** — CUDA Toolkit setup, Python, GPU compatibility
- **Building** — Compile flags, multi-architecture, field selection
- **API Reference** — Complete C/C++ and Python documentation
- **Docker** — Pre-built images, docker-compose, GPU access
- **Benchmarks** — Methodology, performance tuning, optimization
- **Multi-Curve** — Supported fields, compile-time selection
- **Architecture** — CUDA kernel design, memory layout, performance characteristics

---

## Roadmap

- [x] Core CUDA kernel with configurable rounds
- [x] Batch hash and Merkle tree APIs
- [x] Python bindings (ctypes)
- [x] Comprehensive CI/CD
- [ ] Multi-architecture Docker images (GHCR)
- [ ] Automated benchmark on CI badge
- [ ] Multi-curve poseidon (BN254, BLS12-381, Vesta, Pallas)
- [ ] Rust bindings (PyO3 + maturin)
- [ ] WebAssembly (WASM) fallback to CPU
- [ ] Async/streaming API for continuous hashing

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on commit conventions, PR processes, and code style.

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgements

- [Poseidon Paper](https://eprint.iacr.org/2019/458) — Grassi, Khovratovich, Rechberger, Roy, Schofnegger
- [iden3](https://github.com/iden3) — Reference Poseidon implementations
- [Semaphore](https://github.com/appliedzkp/semaphore) — Poseidon parameter generation
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) — Documentation theme

---

<div align="center">

⭐ Star this repo if you find it useful! ⭐

Built with ❤️ and ⚡ on NVIDIA GPUs

</div>
