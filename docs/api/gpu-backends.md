# GPU Backend Architecture

## How the CUDA Kernel Works

![Poseidon Pipeline](../assets/poseidon-pipeline.svg)

### Field Arithmetic

cuda-poseidon operates on **32-bit unsigned field elements**. All arithmetic (add, mul, sub, pow) is done modulo a configurable prime field.

```
prime = 0xFFFFFFFB  (BN254 simplified variant)
```

### Kernel Execution Model

```
┌──────────────┐     ┌─────────────────────────────────┐
│   Host CPU   │ ──▶ │  poseidon_hash_kernel<<<>>>     │
│              │     │  block = 256 threads             │
│  input[H*D]  │     │  each thread: 1 hash            │
│  output[H*D] │ ◀── │                                 │
└──────────────┘     └─────────────────────────────────┘
        │                          │
        │    cudaMemcpyHtoD        │ cudaMemcpyDtoH
        ▼                          ▼
   ┌─────────┐               ┌─────────┐
   │ GPU RAM │               │ GPU RAM │
   │ d_input │               │ d_output│
   └─────────┘               └─────────┘
```

### Round Constants

Round constants are stored in CUDA **constant memory** (cached, broadcast to all threads in a warp):

```cuda
__constant__ u32 POSEIDON_RC[8];
```

Constant memory provides single-cycle read access when all threads in a warp read the same address.

### S-Box Optimization

The S-box computes `x⁷` using 5 modular multiplications (optimal addition chain):

```
x² = x * x
x⁴ = x² * x²  
x⁶ = x⁴ * x²
x⁷ = x⁶ * x
```

This is faster than computing `x⁷` sequentially (6 multiplications) or using exponentiation by squaring.

### Memory Access Pattern

Input data is stored in **Array of Structures (AoS)** layout:

```
index:  [0]  [1]  [2]  [3]  [4]  [5]  ...
        a0   b0   a1   b1   a2   b2   ...
```

Each thread reads 2 consecutive uint32 values. With 256 threads per block and 32 threads per warp, memory accesses are **coalesced** (adjacent threads access adjacent 4-byte words).

## CUDA Compute Capability

| sm | Architecture |PTX Compatibility | Notes |
|----|-------------|-------------------|-------|
| sm_70 | Volta | Baseline | First tensor cores |
| sm_75 | Turing | +FP16 | RTX 20 series |
| sm_80 | Ampere | +TF32 | A100 data center |
| sm_86 | Ampere | +INT8 | RTX 30 series |
| sm_89 | Ada | +FP8 | RTX 40 series |
| sm_90 | Hopper | +Transformer Engine | H100 |

## Multi-GPU Considerations

Current version supports **single GPU** only. Multi-GPU patterns:

1. **Partition batches**: Split input across GPUs, each processes independently
2. **Pinned memory**: Use `cudaMallocHost` for async transfers
3. **Stream overlap**: Overlap kernel execution with host↔device copies

```cpp
// Future: Multi-stream example
cudaStream_t streams[2];
for (int i = 0; i < 2; i++) {
    cudaStreamCreate(&streams[i]);
    poseidon_hash_batch_async(input[i], output[i], n, 8, streams[i]);
}
```

## Performance Characteristics

| Bottleneck | Small Batch (<10K) | Large Batch (>100K) |
|------------|-------------------|---------------------|
| Kernel launch overhead | **Dominant** | Amortized |
| PCIe transfer | Significant | Minor fraction |
| GPU compute | Moderate | **Dominant** |
| Memory bandwidth | Not saturated | Approaching limit |

**Rule of thumb:** For maximum throughput, use batches of 100K–1M pairs.
