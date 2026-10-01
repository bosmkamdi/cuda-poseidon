#!/usr/bin/env python3
"""CPU reference benchmark for CI - no GPU required."""
import time
import random

PRIME32 = 0xFFFFFFFB

def mod_mul(a, b):
    return (a * b) % PRIME32

def mod_pow7(x):
    x2 = mod_mul(x, x)
    x4 = mod_mul(x2, x2)
    x6 = mod_mul(x4, x2)
    return mod_mul(x6, x)

RC = [
    0x43e1f593 % PRIME32, 0x2833e848 % PRIME32,
    0xb85045b6 % PRIME32, 0x30644e72 % PRIME32,
    0x0c4cd6c5 % PRIME32, 0x1cdfd027 % PRIME32,
    0x2090bbff % PRIME32, 0x3a43df9d % PRIME32,
]

def hash_cpu(a, b, rounds=8):
    s0, s1 = a, b
    for r in range(rounds):
        s0 = mod_pow7(s0)
        s1 = mod_pow7(s1)
        tmp = s0
        s0 = (s0 + s1 + RC[r % 8]) % PRIME32
        s1 = (tmp + s1) % PRIME32
    return s0, s1

if __name__ == '__main__':
    for n in [1000, 10000]:
        pairs = [(random.getrandbits(30), random.getrandbits(30)) for _ in range(n)]
        start = time.perf_counter()
        for _ in range(10):
            for a, b in pairs:
                hash_cpu(a, b)
        elapsed = (time.perf_counter() - start) / 10
        hps = n / elapsed
        print(f'  CPU n={n}: {hps:,.0f} hashes/sec ({elapsed*1000:.1f} ms)')
    print('CPU benchmark complete.')
