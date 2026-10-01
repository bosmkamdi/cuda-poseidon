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

// ── Library Info ─────────────────────────────────────────────

/// Returns the name of the field prime compiled into this library.
/// E.g. "BN254", "BLS12-381", "Vesta", "Pallas".
POSEIDON_API const char* poseidon_get_field_name(void);

/// Returns the default round count compiled into this library.
POSEIDON_API int poseidon_get_default_rounds(void);

// ── Lifecycle ────────────────────────────────────────────────

/// Initialize CUDA context and load round constants.
/// Returns 0 on success, non-zero on failure.
POSEIDON_API int poseidon_init(void);

/// Release all GPU resources.
POSEIDON_API void poseidon_cleanup(void);

// ── Hash Operations ──────────────────────────────────────────

/// Batch Poseidon hash on GPU.
///
/// @param input  N * 2 uint32 values (pairs of field elements: a0,b0,a1,b1,...)
/// @param output N * 2 uint32 values (digests: digest_a0,digest_b0,...)
/// @param N      Number of pairs to hash
/// @param rounds Number of Poseidon rounds
///
/// @return 0 on success, negative on failure
POSEIDON_API int poseidon_hash_batch(
    const uint32_t* input,
    uint32_t*       output,
    int             N,
    int             rounds
);

// ── Merkle Tree ──────────────────────────────────────────────

/// Build a complete Merkle tree on GPU using Poseidon compression.
///
/// @param leaves    N * 2 uint32 leaf values
/// @param N         Number of leaves (MUST be a power of 2)
/// @param root_out  2 uint32 values for Merkle root
///
/// @return 0 on success, negative on failure
POSEIDON_API int merkle_build_gpu(
    const uint32_t* leaves,
    int             N,
    uint32_t*       root_out
);

// ── Device Info ──────────────────────────────────────────────

/// Query GPU name and VRAM.
///
/// @param name_out    Buffer for GPU name (min 16 chars)
/// @param name_len    Length of name buffer
/// @param vram_mb_out Pointer to receive VRAM in MB (can be NULL)
POSEIDON_API void poseidon_get_device(
    char* name_out,
    int   name_len,
    int*  vram_mb_out
);

#ifdef __cplusplus
}
#endif

#endif // POSEIDON_CUDA_H
