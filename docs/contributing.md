# Contributing to cuda-poseidon

Thank you for your interest in contributing! This document outlines how to help.

## Ways to Contribute

- 🐛 **Bug Reports**: Open an issue using the bug report template
- ✨ **Feature Requests**: Suggest new curves, APIs, or optimizations
- 📖 **Documentation**: Fix typos, add examples, improve clarity
- 💻 **Code**: Implement features, fix bugs, optimize kernels
- 🧪 **Tests**: Add edge cases and regression tests

## Development Setup

```bash
git clone https://github.com/bosmkamdi/cuda-poseidon.git
cd cuda-poseidon
./build_shared.ps1    # or .sh on Linux
python3 bench/bench.py --quick  # Verify everything works
```

## Commit Convention

```
feat: add poseidon-3 (3-to-1) hash variant
fix: correct mod_mul overflow on large inputs
docs: update benchmark results table
refactor: extract S-box into separate device function
perf: use shared memory for round constants
test: add Merkle tree edge case test (N=1)
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`, `ci`

## Pull Request Process

1. Fork the repo and create a feature branch
2. Make your changes with clear commit messages
3. Ensure existing tests pass: `nvcc ... && ./test_poseidon`
4. Update documentation if adding new APIs
5. Open PR against `main` with description of changes
6. Maintainers will review within 48 hours

## Code Style

### C/C++ (CUDA)

- Kernels: 4-space indent, `__device__ __forceinline__` for small helpers
- Host code: 4-space indent, error checking every CUDA call
- Naming: `snake_case` for functions, `UPPER_CASE` for macros/constants

### Python

- PEP 8 compliant
- Type hints for public API
- Docstrings for all public functions

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.
