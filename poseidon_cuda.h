#ifndef POSEIDON_CUDA_H
#define POSEIDON_CUDA_H

#include <stdint.h>

#ifdef _WIN32
  #ifdef POSEIDON_EXPORTS
    #define POSEIDON_API __declspec(dllexport)
  #else
    #define POSEIDON_API __declspec(dllimport)
  #endif
#else
  #define POSEIDON_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Initialize CUDA context and load constants. Returns 0 on success.
POSEIDON_API int poseidon_init(void);

// Cleanup CUDA resources.
POSEIDON_API void poseidon_cleanup(void);

// Batch Poseidon hash on GPU.
// Input:  N * 2 uint32 values (pairs of field elements)
// Output: N * 2 uint32 values (digests)
// Returns 0 on success.
POSEIDON_API int poseidon_hash_batch(
    const uint32_t* input,
    uint32_t* output,
    int N,
    int rounds  // number of rounds, default 8 for 2-to-1 Poseidon
);

// Build a Merkle tree on GPU using Poseidon as the hash function.
// N must be power of 2
// leaves: N pairs of uint32 field elements
// root_out: 2 uint32 field elements for root
// Returns 0 on success.
POSEIDON_API int merkle_build_gpu(
    const uint32_t* leaves,
    int N,
    uint32_t* root_out
);

// Get GPU device info
POSEIDON_API void poseidon_get_device(char* name_out, int name_len, int* vram_mb_out);

#ifdef __cplusplus
}
#endif

#endif // POSEIDON_CUDA_H
