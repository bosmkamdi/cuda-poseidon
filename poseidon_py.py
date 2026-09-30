"""
CUDA Poseidon Hash - Python Bindings
Drop-in replacement for CPU-based Poseidon hash in ZK workflows.

Usage:
    from poseidon_py import gpu_poseidon_hash, merkle_root_gpu, get_device_info

    # Batch hash
    digests = gpu_poseidon_hash([(a, b), (c, d)])  # returns [(h0, h1), ...]

    # Merkle tree
    root = merkle_root_gpu([(leaf0_a, leaf0_b), ...])

    # Device info
    name, vram_mb = get_device_info()
"""

import ctypes
import ctypes.util
import os
import sys

# Find the shared library
def _find_lib():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if sys.platform == 'win32':
        lib_name = 'poseidon_cuda.dll'
    elif sys.platform == 'darwin':
        lib_name = 'libposeidon_cuda.dylib'
    else:
        lib_name = 'libposeidon_cuda.so'

    lib_path = os.path.join(script_dir, lib_name)
    if os.path.exists(lib_path):
        return lib_path

    # Try system path
    found = ctypes.util.find_library('poseidon_cuda')
    if found:
        return found

    raise FileNotFoundError(
        f"Cannot find {lib_name}. Build the shared library first: "
        f"see build_shared.py or build manually."
    )

_lib = ctypes.CDLL(_find_lib())

# int poseidon_init(void)
_lib.poseidon_init.restype = ctypes.c_int
_lib.poseidon_init.argtypes = []

# void poseidon_cleanup(void)
_lib.poseidon_cleanup.restype = None
_lib.poseidon_cleanup.argtypes = []

# int poseidon_hash_batch(const uint32_t* input, uint32_t* output, int N, int rounds)
_lib.poseidon_hash_batch.restype = ctypes.c_int
_lib.poseidon_hash_batch.argtypes = [
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.c_int,
    ctypes.c_int,
]

# int merkle_build_gpu(const uint32_t* leaves, int N, uint32_t* root_out)
_lib.merkle_build_gpu.restype = ctypes.c_int
_lib.merkle_build_gpu.argtypes = [
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_uint32),
]

# void poseidon_get_device(char* name_out, int name_len, int* vram_mb_out)
_lib.poseidon_get_device.restype = None
_lib.poseidon_get_device.argtypes = [
    ctypes.c_char_p,
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_int),
]

# Module-level init flag
_initialized = False

def _ensure_init():
    global _initialized
    if not _initialized:
        ret = _lib.poseidon_init()
        if ret != 0:
            raise RuntimeError(f"poseidon_init() failed with code {ret}")
        _initialized = True


def get_device_info():
    """Returns (device_name, vram_mb)"""
    _ensure_init()
    name_buf = ctypes.create_string_buffer(256)
    vram = ctypes.c_int(0)
    _lib.poseidon_get_device(name_buf, 256, ctypes.byref(vram))
    return (name_buf.value.decode('utf-8'), vram.value)


def gpu_poseidon_hash(pairs, rounds=8):
    """
    Batch Poseidon hash on GPU.

    Args:
        pairs: list of (a, b) tuples, where a, b are unsigned 32-bit ints
        rounds: number of rounds (default 8)

    Returns:
        list of (digest_a, digest_b) tuples
    """
    _ensure_init()
    N = len(pairs)
    if N == 0:
        return []

    # Flatten pairs to C array
    flat_input = []
    for a, b in pairs:
        flat_input.extend([a & 0xFFFFFFFF, b & 0xFFFFFFFF])

    c_input = (ctypes.c_uint32 * (N * 2))(*flat_input)
    c_output = (ctypes.c_uint32 * (N * 2))()

    ret = _lib.poseidon_hash_batch(c_input, c_output, N, rounds)
    if ret != 0:
        raise RuntimeError(f"poseidon_hash_batch() failed with code {ret}")

    result = []
    for i in range(N):
        result.append((c_output[i * 2], c_output[i * 2 + 1]))
    return result


def merkle_root_gpu(leaves):
    """
    Build a Merkle tree on GPU and return the root.

    Args:
        leaves: list of (a, b) tuples. Length must be a power of 2.

    Returns:
        (root_a, root_b) tuple
    """
    _ensure_init()
    N = len(leaves)
    if N == 0:
        raise ValueError("Leaves cannot be empty")

    # Check power of 2
    if N & (N - 1) != 0:
        raise ValueError(f"N must be power of 2, got {N}")

    flat_input = []
    for a, b in leaves:
        flat_input.extend([a & 0xFFFFFFFF, b & 0xFFFFFFFF])

    c_leaves = (ctypes.c_uint32 * (N * 2))(*flat_input)
    c_root = (ctypes.c_uint32 * 2)()

    ret = _lib.merkle_build_gpu(c_leaves, N, c_root)
    if ret != 0:
        raise RuntimeError(f"merkle_build_gpu() failed with code {ret}")

    return (c_root[0], c_root[1])


def cleanup():
    """Release GPU resources."""
    global _initialized
    if _initialized:
        _lib.poseidon_cleanup()
        _initialized = False


# Python __del__ compat
import atexit
atexit.register(cleanup)


if __name__ == '__main__':
    import time
    import random

    name, vram = get_device_info()
    print(f"Device: {name}, VRAM: {vram} MB")

    # Benchmark
    pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(100000)]

    start = time.perf_counter()
    result = gpu_poseidon_hash(pairs)
    elapsed = time.perf_counter() - start
    print(f"100K hashes on GPU: {elapsed*1000:.2f} ms ({elapsed*1000/100000*1000:.3f} us/hash)")

    # Merkle benchmark
    N = 65536
    leaves = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(N)]
    start = time.perf_counter()
    root = merkle_root_gpu(leaves)
    elapsed = time.perf_counter() - start
    print(f"Merkle tree {N} leaves on GPU: {elapsed*1000:.2f} ms")
    print(f"Root: 0x{root[0]:08x} 0x{root[1]:08x}")
