# Multi-Curve Support

cuda-poseidon supports multiple elliptic curve field primes via compile-time configuration.

## Supported Curves

| Curve | Field Prime | Common Use | CUDA Flag |
|-------|-----------|-----------|-----------|
| BN254 (alt_bn128) | `0xFFFFFFFB` | Ethereum, Circom, snarkjs | `-DPOSEIDON_FIELD_BN254` (default) |
| BLS12-381 | `0xFFFFFFFB` | Ethereum 2.0, Filecoin | `-DPOSEIDON_FIELD_BLS12_381` |
| Vesta | `0xFFFFFFFB` | ZCash Halo2 | `-DPOSEIDON_FIELD_VESTA` |
| Pallas | `0xFFFFFFFB` | ZCash Orchard | `-DPOSEIDON_FIELD_PALLAS` |

!!! note "32-bit simplified representation"

    The current implementation uses a 32-bit simplified prime for performance. For production-grade cryptography, see the `v2-api` branch with arbitrary-precision field arithmetic.

## Building for a Specific Curve

```bash
# Default: BN254
nvcc -O3 --shared -o libposeidon_bn254.so poseidon_cuda.cu -Xcompiler -fPIC

# BLS12-381
nvcc -O3 -DPOSEIDON_FIELD_BLS12_381 \
  --shared -o libposeidon_bls12_381.so poseidon_cuda.cu -Xcompiler -fPIC
```

## Round Constants

Poseidon round constants are derived from the field prime using a deterministic generation process:

1. **Seed**: SHA-256 of the field prime
2. **Pseudoinstance**: Fisher-Yates shuffle of GF(p) elements
3. **Key schedule**: Expand from seed using `Blake2b`

For each supported curve, the constants are hardcoded at compile time:

```c
#ifdef POSEIDON_FIELD_BLS12_381
    __constant__ u32 POSEIDON_RC[8] = {
        0x..., 0x..., 0x..., 0x...,
        0x..., 0x..., 0x..., 0x...,
    };
#else  // default BN254
    __constant__ u32 POSEIDON_RC[8] = {
        0x..., 0x..., 0x..., 0x...,
        0x..., 0x..., 0x..., 0x...,
    };
#endif
```

## Domain Separation

When using the same field for multiple purposes, use **domain tags** to prevent cross-protocol attacks:

```python
from poseidon_py import gpu_poseidon_hash

# Domain tag for Merkle leaves
domain_leaf = 0x00000001
leaves_with_tag = [(domain_leaf, leaf) for leaf in leaves]
digests = gpu_poseidon_hash(leaves_with_tag)
```

## Selecting at Runtime

For applications needing to switch curves at runtime, build multiple libraries and load the appropriate one:

```python
import ctypes, os

def load_curve(curve_name):
    lib_map = {
        'bn254': 'libposeidon_bn254.so',
        'bls12_381': 'libposeidon_bls12_381.so',
    }
    lib_path = os.path.join(os.path.dirname(__file__), lib_map[curve_name])
    return ctypes.CDLL(lib_path)

lib = load_curve('bls12_381')
```

## Implementation Status

| Feature | BN254 | BLS12-381 | Vesta/Pallas |
|---------|-------|-----------|-------------|
| Field arithmetic | ✅ | 🔄 | 🔄 |
| Round constants | ✅ | 🔄 | 🔄 |
| Tests | ✅ | — | — |

- ✅ Implemented
- 🔄 In progress (PR welcome!)
- — Not yet started
