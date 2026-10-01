#!/usr/bin/env python3
"""
CUDA Poseidon Hash — Automated Benchmark Suite

Usage:
    python3 bench.py                     # Full benchmark run
    python3 bench.py --quick             # Quick smoke test only
    python3 bench.py --output results.md # Write Markdown results table
    python3 bench.py --json              # Write results as JSON

Features:
  • Measures hashes/second across multiple batch sizes
  • Reports Merkle tree build throughput (leaves/sec)
  • Compares GPU vs single-threaded CPU Poseidon
  • Exports to JSON or Markdown for CI artifacts
"""

import ctypes
import ctypes.util
import os
import sys
import time
import json
import random
import argparse
from pathlib import Path


# ── Load shared library ──────────────────────────────────────
def _find_lib():
    root = Path(__file__).resolve().parent.parent
    patterns = {
        'win32':  ('poseidon_cuda.dll',),
        'darwin': ('libposeidon_cuda.dylib',),
        'linux':  ('libposeidon_cuda.so',),
    }
    for name in patterns.get(sys.platform, ('libposeidon_cuda.so',)):
        p = root / name
        if p.exists():
            return str(p)
    found = ctypes.util.find_library('poseidon_cuda')
    if found:
        return found
    raise FileNotFoundError(
        "Cannot find poseidon_cuda shared library. Build it first:\n"
        "  Linux:  nvcc -O3 --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC\n"
        "  Windows: .\\build_shared.ps1"
    )


_lib = ctypes.CDLL(_find_lib())
_lib.poseidon_init.restype = ctypes.c_int
_lib.poseidon_init.argtypes = []
_lib.poseidon_hash_batch.restype = ctypes.c_int
_lib.poseidon_hash_batch.argtypes = [
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.c_int, ctypes.c_int,
]
_lib.merkle_build_gpu.restype = ctypes.c_int
_lib.merkle_build_gpu.argtypes = [
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_uint32),
]
_lib.poseidon_get_device.restype = None
_lib.poseidon_get_device.argtypes = [
    ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_int),
]

_initialized = False


def ensure_init():
    global _initialized
    if not _initialized:
        ret = _lib.poseidon_init()
        if ret != 0:
            raise RuntimeError(f"poseidon_init() failed with code {ret}")
        _initialized = True


def get_device_info():
    buf = ctypes.create_string_buffer(256)
    vram = ctypes.c_int(0)
    _lib.poseidon_get_device(buf, 256, ctypes.byref(vram))
    return buf.value.decode(), vram.value


def hash_batch_gpu(pairs, rounds=8):
    n = len(pairs)
    if n == 0:
        return []
    flat = []
    for a, b in pairs:
        flat.extend([a & 0xFFFFFFFF, b & 0xFFFFFFFF])
    c_in  = (ctypes.c_uint32 * (n * 2))(*flat)
    c_out = (ctypes.c_uint32 * (n * 2))()
    ret = _lib.poseidon_hash_batch(c_in, c_out, n, rounds)
    if ret != 0:
        raise RuntimeError(f"poseidon_hash_batch() failed: {ret}")
    return [(c_out[i*2], c_out[i*2+1]) for i in range(n)]


def merkle_root_gpu(leaves):
    n = len(leaves)
    flat = []
    for a, b in leaves:
        flat.extend([a & 0xFFFFFFFF, b & 0xFFFFFFFF])
    c_leaves = (ctypes.c_uint32 * (n * 2))(*flat)
    c_root   = (ctypes.c_uint32 * 2)()
    ret = _lib.merkle_build_gpu(c_leaves, n, c_root)
    if ret != 0:
        raise RuntimeError(f"merkle_build_gpu() failed: {ret}")
    return (c_root[0], c_root[1])


# ── CPU reference implementation ────────────────────────────
_PRIME32 = 0xFFFFFFFB

def _mod_mul(a, b):
    return (a * b) % _PRIME32


def _mod_pow7(x):
    x2 = _mod_mul(x, x)
    x4 = _mod_mul(x2, x2)
    x6 = _mod_mul(x4, x2)
    return _mod_mul(x6, x)


_RC = [
    0x43e1f593 % _PRIME32, 0x2833e848 % _PRIME32,
    0xb85045b6 % _PRIME32, 0x30644e72 % _PRIME32,
    0x0c4cd6c5 % _PRIME32, 0x1cdfd027 % _PRIME32,
    0x2090bbff % _PRIME32, 0x3a43df9d % _PRIME32,
]


def hash_cpu(a, b, rounds=8):
    s0, s1 = a, b
    for r in range(rounds):
        s0 = _mod_pow7(s0)
        s1 = _mod_pow7(s1)
        tmp = s0
        s0 = (s0 + s1 + _RC[r % 8]) % _PRIME32
        s1 = (tmp + s1) % _PRIME32
    return s0, s1


# ── Benchmark runner ────────────────────────────────────────
def run_bench(quick=False):
    ensure_init()
    name, vram = get_device_info()
    print(f"\n{'='*60}")
    print(f"  CUDA Poseidon Hash — Benchmark")
    print(f"  GPU: {name} ({vram} MB VRAM)")
    print(f"{'='*60}\n")

    batch_sizes = [1000, 10000, 100000] if not quick else [1000, 10000]
    merkle_sizes = [1024, 4096, 16384] if not quick else [1024, 4096]

    results = {
        'gpu_name': name,
        'vram_mb': vram,
        'hash': [],
        'merkle': [],
        'cpu_comparison': None,
    }

    # ── GPU Hash benchmark ──
    print("—" * 56)
    print(f"{'Batch Size':>12} | {'Time (ms)':>12} | {'Hashes/sec':>14} | {'µs/hash':>10}")
    print("—" * 56)
    for n in batch_sizes:
        pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(n)]

        # Warmup
        hash_batch_gpu(pairs[:min(100, n)])

        # Timed run
        start = time.perf_counter()
        iters = 10 if n < 100000 else 5
        for _ in range(iters):
            hash_batch_gpu(pairs)
        elapsed = (time.perf_counter() - start) / iters

        hashes_per_sec = n / elapsed
        us_per_hash = elapsed / n * 1e6
        print(f"{n:>12,} | {elapsed*1000:>12.2f} | {hashes_per_sec:>14,.0f} | {us_per_hash:>10.3f}")

        results['hash'].append({
            'batch_size': n,
            'time_ms': round(elapsed * 1000, 2),
            'hashes_per_sec': round(hashes_per_sec),
            'us_per_hash': round(us_per_hash, 3),
        })

    # ── Merkle benchmark ──
    print("\n" + "—" * 56)
    print(f"{'Merkle Size':>12} | {'Time (ms)':>12} | {'Leaves/sec':>14} | {'Height':>8}")
    print("—" * 56)
    for n in merkle_sizes:
        leaves = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(n)]
        height = n.bit_length() - 1

        # Warmup
        merkle_root_gpu(leaves[:min(1024, n)])

        start = time.perf_counter()
        iters = 5
        for _ in range(iters):
            merkle_root_gpu(leaves)
        elapsed = (time.perf_counter() - start) / iters

        leaves_per_sec = n / elapsed
        print(f"{n:>12,} | {elapsed*1000:>12.2f} | {leaves_per_sec:>14,.0f} | {height:>8}")

        results['merkle'].append({
            'leaves': n,
            'height': height,
            'time_ms': round(elapsed * 1000, 2),
            'leaves_per_sec': round(leaves_per_sec),
        })

    # ── CPU vs GPU comparison ──
    if not quick:
        n_compare = 1000
        pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(n_compare)]

        start = time.perf_counter()
        for _ in range(10):
            for a, b in pairs:
                hash_cpu(a, b)
        cpu_elapsed = (time.perf_counter() - start) / 10

        start = time.perf_counter()
        for _ in range(10):
            hash_batch_gpu(pairs)
        gpu_elapsed = (time.perf_counter() - start) / 10

        speedup = cpu_elapsed / gpu_elapsed if gpu_elapsed > 0 else float('inf')
        results['cpu_comparison'] = {
            'sample_size': n_compare,
            'cpu_ms': round(cpu_elapsed * 1000, 2),
            'gpu_ms': round(gpu_elapsed * 1000, 2),
            'speedup': round(speedup, 1),
        }
        print(f"\n{'─'*56}")
        print(f"  CPU vs GPU (n={n_compare}): {speedup:.1f}x speedup")
        print(f"  CPU: {cpu_elapsed*1000:.2f} ms  |  GPU: {gpu_elapsed*1000:.2f} ms")
        print(f"{'─'*56}")

    print(f"\n{'='*60}")
    print("  Benchmark complete.")
    print(f"{'='*60}\n")

    return results


def results_to_markdown(results):
    lines = []
    lines.append("## Benchmark Results\n")
    lines.append(f"**GPU:** {results['gpu_name']} ({results['vram_mb']} MB VRAM)\n")
    lines.append("### Hash Throughput\n")
    lines.append("| Batch Size | Time (ms) | Hashes/sec | µs/hash |")
    lines.append("|-----------:|----------:|-----------:|--------:|")
    for r in results['hash']:
        lines.append(f"| {r['batch_size']:,} | {r['time_ms']} | {r['hashes_per_sec']:,.0f} | {r['us_per_hash']} |")

    lines.append("\n### Merkle Tree Build\n")
    lines.append("| Leaves | Height | Time (ms) | Leaves/sec |")
    lines.append("|-------:|-------:|----------:|-----------:|")
    for r in results['merkle']:
        lines.append(f"| {r['leaves']:,} | {r['height']} | {r['time_ms']} | {r['leaves_per_sec']:,.0f} |")

    if results.get('cpu_comparison'):
        c = results['cpu_comparison']
        lines.append("\n### CPU vs GPU\n")
        lines.append(f"- **Sample:** {c['sample_size']} hashes (single-threaded CPU vs GPU batch)")
        lines.append(f"- **CPU:** {c['cpu_ms']} ms")
        lines.append(f"- **GPU:** {c['gpu_ms']} ms")
        lines.append(f"- **Speedup:** {c['speedup']}x")

    return "\n".join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='CUDA Poseidon Benchmark')
    parser.add_argument('--quick', action='store_true', help='Quick smoke test only')
    parser.add_argument('--json', action='store_true', help='Output results as JSON')
    parser.add_argument('--output', type=str, help='Write results to file (auto-detects .md/.json)')
    args = parser.parse_args()

    try:
        results = run_bench(quick=args.quick)
    except Exception as e:
        print(f"\n❌ Benchmark failed: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json or (args.output and args.output.endswith('.json')):
        output = json.dumps(results, indent=2)
        if args.output:
            Path(args.output).write_text(output)
            print(f"Results written to {args.output}")
        else:
            print(output)
    elif args.output:
        md = results_to_markdown(results)
        Path(args.output).write_text(md)
        print(f"Markdown results written to {args.output}")
