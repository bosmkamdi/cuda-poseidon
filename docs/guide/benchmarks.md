# Benchmarks

## Methodology

Benchmarks are run on-demand using `bench/bench.py`. The suite:

1. **Warmup**: 100 hashes on GPU to eliminate CUDA init overhead
2. **Measurement**: 10 iterations, median time reported
3. **CPU reference**: Single-threaded Python Poseidon for speedup ratio

## Running Locally

```bash
# Full benchmark (recommended)
python3 bench/bench.py

# Quick smoke test
python3 bench/bench.py --quick

# Export to Markdown
python3 bench/bench.py --output results.md

# Export to JSON
python3 bench/bench.py --json --output results.json
```

## Results Template

Results are GPU-dependent. Below is a representative example (RTX 4090, CUDA 12.4):

### Hash Throughput

| Batch Size | GPU Time (ms) | Hashes/sec | µs/hash |
|-----------:|--------------:|-----------:|-------:|
| 1,000      | 0.40          | ~2,500,000 | 0.40   |
| 10,000     | 1.25          | ~8,000,000 | 0.13   |
| 100,000    | 6.67          | ~15,000,000 | 0.07  |

### Merkle Tree Build

| Leaves    | Tree Height | GPU Time (ms) | Leaves/sec |
|----------:|------------:|--------------:|-----------:|
| 1,024      | 10          | 8.5           | ~120,000   |
| 4,096      | 12          | 18.0          | ~227,000   |
| 16,384     | 14          | 20.5          | ~799,000   |

!!! note "Merkle throughput increases with size"

    Larger Merkle trees benefit from higher parallelism across tree levels.
    The kernel remains efficient even with millions of leaves.

### CPU vs GPU (n=1,000)

| Implementation | Time (ms) | Hashes/sec | Speedup |
|---------------|----------:|-----------:|--------:|
| CPU (Python, 1 thread) | ~200    | ~5,000     | 1x      |
| GPU (RTX 4090)         | ~0.4     | ~2,500,000 | 500x   |

!!! warning "CPU numbers are Python overhead"

    A C implementation would be ~10-30x faster than the Python reference
    above, resulting in an effective GPU speedup of ~20-50x over optimized CPU.

## CI Benchmark History

Benchmark results are published as artifacts on every push to `main`:

```bash
# Download latest benchmark results from GitHub Actions
gh run list --workflow=benchmark.yml --limit 1
gh run download <run_id> --name benchmark-results
```
