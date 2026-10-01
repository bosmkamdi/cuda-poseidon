# C/C++ API Reference

Full API for integrating cuda-poseidon in C/C++ projects.

## Functions

### `poseidon_init`

```c
int poseidon_init(void);
```

Initializes CUDA context and loads round constants to GPU constant memory. Must be called before any hash operation.

**Returns:** `0` on success, non-zero on failure (!!If initialization fails, check that a CUDA-capable GPU is available and that the NVIDIA driver is installed.!!)

!!! tip "Idempotent — safe to call multiple times"

    Initialization is checked via and internal flag and skips if already initialized.

---

### `poseidon_hash_batch`

```c
int poseidon_hash_batch(
    const uint32_t* input,
    uint32_t* output,
    int n,
    int rounds
);
```

Computes Poseidon hashes for `n` pairs of field elements on the GPU.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | `const uint32_t*` | Pointer to `n * 2` uint32 values (pairs: `[a0, b0, a1, b1, ...]`) |
| `output` | `uint32_t*` | Output buffer of size `n * 2` uint32 (digests) |
| `n` | `int` | Number of pairs to hash |
| `rounds` | `int` | Number of Poseidon rounds (typically `8` for 2-to-1) |

**Returns:** `0` on success

**Performance:**

| Batch Size | Approximate Time (RTX 4090) |
|-----------:|----------------------------:|
| 1,000      | ~0.4 ms                     |
| 10,000     | ~1.3 ms                     |
| 100,000    | ~6.7 ms                     |
| 1,000,000  | ~55 ms                      |

---

### `merkle_build_gpu`

```c
int merkle_build_gpu(
    const uint32_t* leaves,
    int n,
    uint32_t* root_out
);
```

Builds a complete binary Merkle tree on GPU using Poseidon as the compression function.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `leaves` | `const uint32_t*` | `n * 2` uint32 leaf values (pairs of field elements) |
| `n` | `int` | Number of leaves, **must be a power of 2** |
| `root_out` | `uint32_t*` | 2-element buffer for Merkle root |

**Returns:** `0` on success, `-1` if `n` is not power of 2

---

### `poseidon_get_device`

```c
void poseidon_get_device(
    char* name_out,
    int name_len,
    int* vram_mb_out
);
```

Queries NVIDIA driver for GPU name and installed VRAM.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name_out` | `char*` | Output buffer for GPU name |
| `name_len` | `int` | Buffer size in bytes (including null terminator) |
| `vram_mb_out` | `int*` | Output pointer for VRAM size in MB (can be NULL) |

---

### `poseidon_cleanup`

```c
void poseidon_cleanup(void);
```

Releases all GPU resources (device buffers, CUDA context). Call before program exit.

## Usage Example

```c
#include "poseidon_cuda.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
    // 1. Init GPU
    if (poseidon_init() != 0) {
        fprintf(stderr, "No CUDA device found.\n");
        return 1;
    }

    // 2. Check device
    char name[256];
    int vram = 0;
    poseidon_get_device(name, sizeof(name), &vram);
    printf("GPU: %s (%d MB)\n", name, vram);

    // 3. Batch hash 1M inputs
    int n = 1000000;
    uint32_t* input  = malloc(n * 2 * sizeof(uint32_t));
    uint32_t* output = malloc(n * 2 * sizeof(uint32_t));

    for (int i = 0; i < n * 2; i++) {
        input[i] = (uint32_t)rand();
    }

    poseidon_hash_batch(input, output, n, 8);
    printf("Hash[0]: 0x%08x 0x%08x\n", output[0], output[1]);

    // 4. Merkle tree
    int n_leaves = 65536;
    uint32_t* leaves = malloc(n_leaves * 2 * sizeof(uint32_t));
    for (int i = 0; i < n_leaves * 2; i++) {
        leaves[i] = (uint32_t)rand();
    }
    uint32_t root[2];
    merkle_build_gpu(leaves, n_leaves, root);
    printf("Merkle root: 0x%08x 0x%08x\n", root[0], root[1]);

    // 5. Cleanup
    poseidon_cleanup();
    free(input);
    free(output);
    free(leaves);
    return 0;
}
```

## Linking

### Linux

```bash
gcc -o myapp myapp.c -L/path/to/cuda-poseidon -I/path/to/cuda-poseidon -lposeidon_cuda
export LD_LIBRARY_PATH=/path/to/cuda-poseidon:$LD_LIBRARY_PATH
./myapp
```

### Windows

```ps1
cl myapp.c /I path\to\cuda-poseidon /link path\to\cuda-poseidon\poseidon_cuda.lib
# Ensure poseidon_cuda.dll is in PATH or same folder
.\myapp.exe
```
