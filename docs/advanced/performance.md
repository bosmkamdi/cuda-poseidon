# Performance Tuning Guide

## Optimal Batch Size

The GPU is most efficient when fully saturated:

| Batch Size | Utilization | Throughput |
|-----------:|------------:|-----------:|
| 1K          | ~5%         | Low        |
| 10K         | ~25%        | Medium     |
| 100K        | ~75%        | High       |
| 1M+         | ~95%        | Peak       |

!!! tip "Rule of thumb"

    Always batch at least **100,000 pairs** for production workloads.
    Below that, you're leaving performance on the table.

## Memory Management

Global device buffers are reused across calls to avoid repeated `cudaMalloc`/`cudaFree`:

```c
// After first call, buffers are cached internally
poseidon_hash_batch(input_a, output_a, 100000, 8);  // allocates
poseidon_hash_batch(input_b, output_b, 100000, 8);  // reuses
```

Buffers auto-grow if a larger batch is requested. Shrinking is deferred to cleanup.

## Avoiding PCIe Bottleneck

For small, latency-sensitive operations:

1. **Use pinned memory** on host side:
   ```c
   uint32_t* h_input;
   cudaMallocHost(&h_input, size);  // pinned = faster DMA
   ```

2. **Keep data on GPU**: If chaining multiple operations, use device pointers directly:
   ```c
   // Instead of: GPU → Host → GPU between steps
   // Device → Device avoids PCIe round trip
   poseidon_hash_batch(d_input, d_temp, n, 4);
   poseidon_hash_batch(d_temp, d_output, n/2, 4);
   ```

## Profiling with Nsight

```bash
# Compute-only profiling
nsys profile -o poseidon_report ./bench/bench_cpu

# Detailed kernel metrics
ncu --set full ./bench/bench_cpu
```

Key metrics to watch:

| Metric | Bottleneck | What it tells you |
|--------|-----------|-------------------|
| `sm__throughput` | Shader array | % of peak SM utilization |
| | `dram__throughput` | Memory | % of peak memory bandwidth |
| `l1tex__throughput` | L1/texture cache | % of peak cache bandwidth |
| `launch__occupancy` | Register usage | % of max warps per SM |

## Compiler Optimizations

| Flag | Effect | Risk |
|------|--------|------|
| `--use_fast_math` | Replaces `mod_mul` with bitwise when possible | Slight precision loss |
| `-O3` | Maximum optimization | Larger binary |
| `--maxrregcount=N` | Limit registers per thread | May reduce occupancy |
| `-Xptxas -v` | Show register/shared memory stats | Diagnostic only |

## Multi-Stream Overlap

For pipelined workloads (hash + transfer simultaneously):

```cpp
cudaStream_t s1, s2;
cudaStreamCreate(&s1);
cudaStreamCreate(&s2);

// Overlap: hash chunk 2 while chunk 1 is transferring
cudaMemcpyAsync(d_a, h_a, sz1, cudaMemcpyHostToDevice, s1);
poseidon_hash_kernel<<<blocks, threads, 0, s1>>>(d_a, d_c, n1, 8);
cudaMemcpyAsync(h_c, d_c, sz1, cudaMemcpyDeviceToHost, s1);

cudaMemcpyAsync(d_b, h_b, sz2, cudaMemcpyHostToDevice, s2);
poseidon_hash_kernel<<<blocks, threads, 0, s2>>>(d_b, d_d, n2, 8);
```

## Warmup Strategy

The first kernel launch includes ~100µs CUDA context init. For reproducible benchmarks:

```python
# Always warmup first
warmup_pairs = [(0, 1)] * 1000
gpu_poseidon_hash(warmup_pairs)

# Now benchmark
start = time.perf_counter()
result = gpu_poseidon_hash(pairs)
elapsed = time.perf_counter() - start
```
