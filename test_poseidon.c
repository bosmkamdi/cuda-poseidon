// Test + Benchmark for CUDA Poseidon library
// Compiled as standalone executable (links with poseidon_cuda.cu)
#include "poseidon_cuda.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <string.h>

typedef unsigned int u32;
typedef unsigned long long u64;
#define PRIME32 0xFFFFFFFBU

static double now_ms() {
    return (double)clock() * 1000.0 / CLOCKS_PER_SEC;
}

// CPU Poseidon hash (same algorithm as GPU for correctness verification)
static void poseidon_cpu(const u32* input, u32* output, int N, int rounds) {
    u32 rc[8] = {
        0x43e1f593U % PRIME32, 0x2833e848U % PRIME32,
        0xb85045b6U % PRIME32, 0x30644e72U % PRIME32,
        0x0c4cd6c5U % PRIME32, 0x1cdfd027U % PRIME32,
        0x2090bbffU % PRIME32, 0x3a43df9dU % PRIME32
    };

    for (int i = 0; i < N; i++) {
        u32 s0 = input[i*2], s1 = input[i*2+1];
        for (int r = 0; r < rounds; r++) {
            // x^7 mod prime
            u32 x2, x4, x6;
            x2 = (u32)(((u64)s0*s0)%PRIME32);
            x4 = (u32)(((u64)x2*x2)%PRIME32);
            x6 = (u32)(((u64)x4*x2)%PRIME32);
            s0 = (u32)(((u64)x6*s0)%PRIME32);

            x2 = (u32)(((u64)s1*s1)%PRIME32);
            x4 = (u32)(((u64)x2*x2)%PRIME32);
            x6 = (u32)(((u64)x4*x2)%PRIME32);
            s1 = (u32)(((u64)x6*s1)%PRIME32);

            // Match GPU: mod_add uses u64 % PRIME32
            u32 tmp = s0;
            s0 = (u32)(((u64)s0 + s1 + rc[r%8]) % PRIME32);
            s1 = (u32)(((u64)tmp + s1) % PRIME32);
        }
        output[i*2] = s0;
        output[i*2+1] = s1;
    }
}

int main(int argc, char** argv) {
    char dev_name[256];
    int vram_mb;
    poseidon_get_device(dev_name, sizeof(dev_name), &vram_mb);

    printf("=========================================\n");
    printf("  CUDA Poseidon Hash Library v0.1\n");
    printf("  Device: %s\n", dev_name);
    printf("  VRAM:   %d MB\n", vram_mb);
    printf("=========================================\n\n");

    if (poseidon_init() != 0) {
        fprintf(stderr, "Failed to initialize CUDA Poseidon\n");
        return 1;
    }

    // Test 1: Correctness
    printf("TEST 1: Correctness Verification\n");
    {
        int N = 100;
        u32 input[200], gpu_out[200], cpu_out[200];
        srand(42);
        for (int i = 0; i < N*2; i++) input[i] = ((u32)rand() << 16) ^ (u32)rand();

        poseidon_hash_batch(input, gpu_out, N, 8);
        poseidon_cpu(input, cpu_out, N, 8);

        int errors = 0;
        for (int i = 0; i < N*2; i++) {
            if (gpu_out[i] != cpu_out[i]) {
                if (errors < 5) {
                    printf("  MISMATCH at [%d]: GPU=0x%08x CPU=0x%08x\n",
                           i, gpu_out[i], cpu_out[i]);
                }
                errors++;
            }
        }
        if (errors == 0) {
            printf("  PASS: %d hashes match CPU reference\n", N);
        } else {
            printf("  FAIL: %d / %d mismatches\n", errors, N*2);
        }
    }

    // Test 2: Performance Benchmark
    printf("\nTEST 2: Poseidon Hash Performance\n");
    printf("%-10s %-12s %-12s %-10s\n", "N", "CPU(ms)", "GPU(ms)", "Speedup");
    printf("-----------------------------------------------\n");

    int sizes[] = {1000, 10000, 100000, 500000};
    for (int t = 0; t < 4; t++) {
        int N = sizes[t];
        u32* input = (u32*)malloc(N * 2 * sizeof(u32));
        u32* output = (u32*)malloc(N * 2 * sizeof(u32));

        srand(123);
        for (int i = 0; i < N*2; i++) input[i] = ((u32)rand() << 16) ^ (u32)rand();

        // CPU benchmark
        double cpu_start = now_ms();
        poseidon_cpu(input, output, N, 8);
        double cpu_ms = now_ms() - cpu_start;

        // GPU benchmark (average of 100 runs)
        int threads = 256;
        int blocks = (N + threads - 1) / threads;

        // Warmup
        poseidon_hash_batch(input, output, N, 8);

        double gpu_start = now_ms();
        for (int rep = 0; rep < 100; rep++) {
            poseidon_hash_batch(input, output, N, 8);
        }
        double gpu_ms = (now_ms() - gpu_start) / 100.0;

        printf("%-10d %-12.2f %-12.3f %-10.1fx\n",
               N, cpu_ms, gpu_ms, cpu_ms / gpu_ms);

        free(input);
        free(output);
    }

    // Test 3: Merkle Tree Build
    printf("\nTEST 3: Merkle Tree (GPU vs CPU)\n");
    {
        int N = 65536; // 2^16 leaves
        u32* leaves = (u32*)malloc(N * 2 * sizeof(u32));
        srand(777);
        for (int i = 0; i < N*2; i++) leaves[i] = ((u32)rand() << 16) ^ (u32)rand();

        u32 gpu_root[2], cpu_root[2];

        // GPU merkle
        double gpu_start = now_ms();
        merkle_build_gpu(leaves, N, gpu_root);
        double gpu_ms = now_ms() - gpu_start;

        // CPU merkle
        double cpu_start = now_ms();
        int pairs = N;
        u32* cur = (u32*)malloc(N * 2 * sizeof(u32));
        memcpy(cur, leaves, N * 2 * sizeof(u32));
        u32* nxt = (u32*)malloc(N * 2 * sizeof(u32));
        while (pairs > 1) {
            poseidon_cpu(cur, nxt, pairs, 8);
            u32* tmp = cur;
            cur = nxt;
            nxt = tmp;
            pairs /= 2;
        }
        cpu_root[0] = cur[0];
        cpu_root[1] = cur[1];
        double cpu_ms = now_ms() - cpu_start;
        free(cur);
        free(nxt);

        int match = (gpu_root[0] == cpu_root[0] && gpu_root[1] == cpu_root[1]);
        printf("  N=%d leaves (%d levels)\n", N, (int)log2(N));
        printf("  GPU root: 0x%08x 0x%08x (%.2f ms)\n", gpu_root[0], gpu_root[1], gpu_ms);
        printf("  CPU root: 0x%08x 0x%08x (%.2f ms)\n", cpu_root[0], cpu_root[1], cpu_ms);
        printf("  Match: %s | Speedup: %.1fx\n", match ? "YES" : "NO!!!", cpu_ms / gpu_ms);
        free(leaves);
    }

    poseidon_cleanup();
    printf("\nDone.\n");
    return 0;
}
