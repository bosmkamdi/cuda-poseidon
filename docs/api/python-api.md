# Python API Reference

All Python bindings use ctypes — no external dependencies.

## Functions

### `get_device_info`

```python
def get_device_info() -> tuple[str, int]
```

Returns GPU name and VRAM in MB.

**Returns:** `(device_name, vram_mb)`

```python
name, vram = get_device_info()
print(f"Running on: {name} ({vram} MB)")
```

---

### `gpu_poseidon_hash`

```python
def gpu_poseidon_hash(
    pairs: list[tuple[int, int]],
    rounds: int = 8
) -> list[tuple[int, int]]
```

Batch Poseidon hash on GPU.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pairs` | `list[tuple[int, int]]` | — | List of `(a, b)` tuples. `a` and `b` should be 32-bit field elements. |
| `rounds` | `int` | `8` | Number of Poseidon rounds |

**Returns:** List of `(digest_a, digest_b)` tuples, same length as input

```python
from poseidon_py import gpu_poseidon_hash
import random

pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(100_000)]
digests = gpu_poseidon_hash(pairs)
print(f"First digest: 0x{digests[0][0]:08x}")
```

---

### `merkle_root_gpu`

```python
def merkle_root_gpu(
    leaves: list[tuple[int, int]]
) -> tuple[int, int]
```

Build Merkle tree on GPU and return root.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `leaves` | `list[tuple[int, int]]` | Leaf nodes. **Length must be power of 2.** |

**Returns:** `(root_a, root_b)` tuple

**Raises:**

- `ValueError` if `leaves` is empty or length is not a power of 2
- `RuntimeError` if GPU call fails

```python
from poseidon_py import merkle_root_gpu
import random

# 2^16 = 65536 leaves
leaves = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(65536)]
root = merkle_root_gpu(leaves)
print(f"Merkle root: 0x{root[0]:08x}")
```

---

### `cleanup`

```python
def cleanup() -> None
```

Releases GPU resources. Called automatically at interpreter exit.

## Complete Example

```python
#!/usr/bin/env python3
"""
Generate 1M Merkle proofs using cuda-poseidon.
"""
import random
import time
from poseidon_py import gpu_poseidon_hash, merkle_root_gpu, get_device_info

def main():
    name, vram = get_device_info()
    print(f"GPU: {name} ({vram} MB)")

    # Generate leaves
    n_leaves = 2**20
    print(f"Generating {n_leaves:,} leaves...")
    leaves = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(n_leaves)]

    # Warmup
    gpu_poseidon_hash(leaves[:1000])

    # Benchmark hash
    start = time.perf_counter()
    digests = gpu_poseidon_hash(leaves)
    elapsed = time.perf_counter() - start
    print(f"Hash 1M pairs: {elapsed*1000:.1f} ms ({n_leaves/elapsed:,.0f} hashes/sec)")

    # Benchmark Merkle
    start = time.perf_counter()
    root = merkle_root_gpu(leaves)
    elapsed = time.perf_counter() - start
    print(f"Merkle tree (1M leaves): {elapsed*1000:.1f} ms")
    print(f"Root: 0x{root[0]:08x} 0x{root[1]:08x}")

if __name__ == '__main__':
    main()
```

## Error Handling

```python
from poseidon_py import gpu_poseidon_hash

try:
    result = gpu_poseidon_hash([(123, 456)])
except RuntimeError as e:
    if "No CUDA device" in str(e):
        print("GPU not available — falling back to CPU")
    else:
        raise
```

## Performance Tips

1. **Use batches**: Single hash calls have ~100µs overhead. Batch thousands at once for efficiency.
2. **Reuse pairs**: If computing multiple rounds, reuse the same list to avoid GC.
3. **Avoid tiny batches**: Batches < 1000 elements don't saturate GPU cores.
4. **Prefer uint32 inputs**: No modulo reduction needed; Python handles this automatically.
