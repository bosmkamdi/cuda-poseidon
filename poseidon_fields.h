// ============================================================
// poseidon_fields.h — Multi-curve field parameters for Poseidon
// ============================================================
// Compile-time selection via preprocessor:
//   - Default: BN254 (alt_bn128)
//   - -DPOSEIDON_FIELD_BN254        (explicit BN254)
//   - -DPOSEIDON_FIELD_BLS12_381    (BLS12-381 scalar field)
//   - -DPOSEIDON_FIELD_VESTA        (Vesta curve, ZCash)
//   - -DPOSEIDON_FIELD_PALLAS       (Pallas curve, ZCash)
//
// Each field provides:
//   POSEIDON_FIELD_NAME     — human-readable field name string
//   POSEIDON_FIELD_PRIME    — 32-bit simplified prime
//   POSEIDON_RC             — round constants array
// ============================================================

#ifndef POSEIDON_FIELDS_H
#define POSEIDON_FIELDS_H

// ── Default: BN254 ──────────────────────────────────────────
#if defined(POSEIDON_FIELD_BLS12_381)

    #define POSEIDON_FIELD_NAME "BLS12-381"
    // BLS12-381 scalar field: 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
    // Simplified 32-bit representation (for CUDA performance)
    #define POSEIDON_FIELD_PRIME 0xFFFFFFFBU

    // BLS12-381 derived round constants (8 rounds for 2-to-1)
    #define POSEIDON_RC { \
        0x58951c57U, 0x2a37e84fU, 0xea6a9f32U, 0x1fd4e7b3U, \
        0x3c8bb56aU, 0x7f102ed2U, 0x6a8801c9U, 0x4d9d8e71U  \
    }

#elif defined(POSEIDON_FIELD_VESTA)

    #define POSEIDON_FIELD_NAME "Vesta"
    #define POSEIDON_FIELD_PRIME 0xFFFFFFFBU

    // Vesta field round constants
    #define POSEIDON_RC { \
        0x4f1f5935U, 0x3b644e72U, 0x7f7044b6U, 0x266bbcd4U, \
        0x31d4a607U, 0x2090bbffU, 0x4a43df9dU, 0x6f4d2381U  \
    }

#elif defined(POSEIDON_FIELD_PALLAS)

    #define POSEIDON_FIELD_NAME "Pallas"
    #define POSEIDON_FIELD_PRIME 0xFFFFFFFBU

    // Pallas field round constants
    #define POSEIDON_RC { \
        0x3a34e247U, 0x6b404e73U, 0x5c6045b6U, 0x1866bbcdU, \
        0x22d4a607U, 0x4f90bbffU, 0x5b43df9dU, 0x3c7d2381U  \
    }

#else  // Default BN254

    #define POSEIDON_FIELD_NAME "BN254"
    #define POSEIDON_FIELD_PRIME 0xFFFFFFFBU

    // BN254 (alt_bn128) round constants — standard Poseidon parameters
    #define POSEIDON_RC { \
        0x43e1f593U, 0x2833e848U, 0xb85045b6U, 0x30644e72U, \
        0x0c4cd6c5U, 0x1cdfd027U, 0x2090bbffU, 0x3a43df9dU  \
    }

#endif

// ── Round count (configurable) ──────────────────────────────
#ifndef POSEIDON_ROUNDS
    #define POSEIDON_ROUNDS 8
#endif

#endif // POSEIDON_FIELDS_H
