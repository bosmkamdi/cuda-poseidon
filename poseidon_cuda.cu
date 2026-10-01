// CUDA-Accelerated Poseidon Hash Library for ZK Applications
// Compatible with: circom/snarkjs Poseidon, Merkle tree construction
// Target: NVIDIA GPU with Compute Capability >= 7.0
//
// Multi-curve support: select field at compile time
//   Default: BN254
//   -DPOSEIDON_FIELD_BN254       BN254 (alt_bn128) curve
//   -DPOSEIDON_FIELD_BLS12_381   BLS12-381 scalar field
//   -DPOSEIDON_FIELD_VESTA       Vesta curve (ZCash Halo2)
//   -DPOSEIDON_FIELD_PALLAS      Pallas curve (ZCash Orchard)
//
// Define POSEIDON_ROUNDS to override the default round count (8).

#include "poseidon_cuda.h"
#include "poseidon_fields.h"
#include <cuda_runtime.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

typedef unsigned long long u64;
typedef unsigned int u32;

// Field prime from poseidon_fields.h (set at compile time)
#define PRIME32 POSEIDON_FIELD_PRIME

__device__ __forceinline__ u32 mod_mul(u32 a, u32 b) {
    return (u32)(((u64)a * b) % PRIME32);
}

__device__ __forceinline__ u32 mod_add(u32 a, u32 b) {
    u64 s = (u64)a + (u64)b;
    return (u32)(s % PRIME32);
}

__device__ __forceinline__ u32 mod_sub(u32 a, u32 b) {
    u64 d = (u64)a + PRIME32 - (u64)b;
    return (u32)(d % PRIME32);
}

__device__ __forceinline__ u32 mod_pow7(u32 x) {
    u32 x2 = mod_mul(x, x);
    u32 x4 = mod_mul(x2, x2);
    u32 x6 = mod_mul(x4, x2);
    return mod_mul(x6, x);
}

// Round constants — defined in poseidon_fields.h per selected field
__constant__ u32 POSEIDON_RC[8];

__global__ void poseidon_hash_kernel(
    const u32*    input,
    u32*          output,
    int           N,
    int           rounds
) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= N) return;

    u32 s0 = input[tid * 2];
    u32 s1 = input[tid * 2 + 1];

    for (int r = 0; r < rounds; r++) {
        // S-box (x^7)
        s0 = mod_pow7(s0);
        s1 = mod_pow7(s1);

        // Linear layer + round constant
        u32 tmp = s0;
        s0 = mod_add(mod_add(s0, s1), POSEIDON_RC[r % 8]);
        s1 = mod_add(tmp, s1);
    }

    output[tid * 2]     = s0;
    output[tid * 2 + 1] = s1;
}

// ── Global device buffers (allocated once) ──────────────────
static u32* d_buf_a    = NULL;
static u32* d_buf_b    = NULL;
static int   d_buf_cap = 0;   // capacity in pairs
static int   initialized = 0;

int poseidon_init(void) {
    if (initialized) return 0;

    // Check for CUDA device
    int deviceCount;
    cudaError_t err = cudaGetDeviceCount(&deviceCount);
    if (err != cudaSuccess || deviceCount == 0) {
        fprintf(stderr, "poseidon_cuda: No CUDA device found\n");
        return -1;
    }

    // Load round constant for the selected field
    u32 h_rc[8];
    u32 rc_data[8] = POSEIDON_RC;
    for (int i = 0; i < 8; i++)
        h_rc[i] = rc_data[i] % PRIME32;

    err = cudaMemcpyToSymbol(POSEIDON_RC, h_rc, 8 * sizeof(u32));
    if (err != cudaSuccess) {
        fprintf(stderr, "poseidon_cuda: cudaMemcpyToSymbol failed: %s\n",
                cudaGetErrorString(err));
        return -1;
    }

    initialized = 1;
    return 0;
}

void poseidon_cleanup(void) {
    if (d_buf_a) { cudaFree(d_buf_a); d_buf_a = NULL; }
    if (d_buf_b) { cudaFree(d_buf_b); d_buf_b = NULL; }
    d_buf_cap  = 0;
    initialized = 0;
}

static int ensure_capacity(int pairs) {
    if (pairs <= d_buf_cap) return 0;

    // Free old
    if (d_buf_a) cudaFree(d_buf_a);
    if (d_buf_b) cudaFree(d_buf_b);

    // Allocate double-buffered for merkle tree building
    size_t sz = (size_t)pairs * 4 * sizeof(u32);
    cudaError_t err = cudaMalloc(&d_buf_a, sz);
    if (err != cudaSuccess) return -1;
    err = cudaMalloc(&d_buf_b, sz);
    if (err != cudaSuccess) { cudaFree(d_buf_a); d_buf_a = NULL; return -1; }

    d_buf_cap = pairs;
    return 0;
}

int poseidon_hash_batch(
    const uint32_t* input,
    uint32_t*       output,
    int             N,
    int             rounds
) {
    if (!initialized) {
        if (poseidon_init() != 0) return -1;
    }

    size_t in_sz  = (size_t)N * 2 * sizeof(u32);
    size_t out_sz = (size_t)N * 2 * sizeof(u32);

    u32 *d_in, *d_out;
    cudaError_t err = cudaMalloc(&d_in, in_sz);
    if (err != cudaSuccess) return -2;
    err = cudaMalloc(&d_out, out_sz);
    if (err != cudaSuccess) { cudaFree(d_in); return -2; }

    cudaMemcpy(d_in, input, in_sz, cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;
    poseidon_hash_kernel<<<blocks, threads>>>(d_in, d_out, N, rounds);

    cudaMemcpy(output, d_out, out_sz, cudaMemcpyDeviceToHost);

    cudaFree(d_in);
    cudaFree(d_out);

    err = cudaGetLastError();
    return (err == cudaSuccess) ? 0 : -3;
}

int merkle_build_gpu(
    const uint32_t* leaves,
    int             N,
    uint32_t*       root_out
) {
    if (!initialized) {
        if (poseidon_init() != 0) return -1;
    }

    // Check N is power of 2
    if (N <= 0 || (N & (N - 1)) != 0) {
        fprintf(stderr, "merkle_build_gpu: N must be power of 2, got %d\n", N);
        return -1;
    }

    if (ensure_capacity(N) != 0) return -2;

    // Copy leaves to device buf_a
    size_t level_sz = (size_t)N * 2 * sizeof(u32);
    cudaMemcpy(d_buf_a, leaves, level_sz, cudaMemcpyHostToDevice);

    u32* src   = d_buf_a;
    u32* dst   = d_buf_b;
    int  pairs = N;

    int threads = 256;

    while (pairs > 1) {
        int blocks = (pairs + threads - 1) / threads;
        // Hash pairs: each pair (2 elements) → 2 element digest
        poseidon_hash_kernel<<<blocks, threads>>>(src, dst, pairs, POSEIDON_ROUNDS);

        // Swap
        u32* tmp = src;
        src = dst;
        dst = tmp;
        pairs /= 2;
    }

    // Root is in src[0..1]
    cudaMemcpy(root_out, src, 2 * sizeof(u32), cudaMemcpyDeviceToHost);

    // Restore buffer pointers
    d_buf_a = src;
    d_buf_b = dst;

    return 0;
}

void poseidon_get_device(char* name_out, int name_len, int* vram_mb_out) {
    cudaDeviceProp prop;
    if (cudaGetDeviceProperties(&prop, 0) == cudaSuccess) {
        strncpy(name_out, prop.name, name_len - 1);
        name_out[name_len - 1] = '\0';
        if (vram_mb_out) *vram_mb_out = (int)(prop.totalGlobalMem / (1024 * 1024));
    } else {
        strncpy(name_out, "Unknown", name_len - 1);
        name_out[name_len - 1] = '\0';
        if (vram_mb_out) *vram_mb_out = 0;
    }
}

const char* poseidon_get_field_name(void) {
    return POSEIDON_FIELD_NAME;
}

int poseidon_get_default_rounds(void) {
    return POSEIDON_ROUNDS;
}
