# Changelog

All notable changes to cuda-poseidon are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Multi-stage Dockerfile with runtime and Python targets
- Automated benchmark suite (`bench/bench.py`) with CPU vs GPU comparison
- MkDocs documentation site with Material theme
- GitHub Actions workflows for docs deploy, benchmarks, and Docker publish
- CPU reference implementation in Python for speedup comparison
- JSON and Markdown export for benchmark results

### Planned

- Multi-curve support (BN254, BLS12-381 field parameters)
- v2 API redesign with CUDA streams and async execution

## [0.2.0] — 2026-01-XX

### Added

- Restructured project with .github directory (build workflow, issue templates)
- CONTRIBUTING.md and SECURITY.md
- Comprehensive README with badges, API docs, benchmarks
- Build scripts for Windows (`build.ps1`, `build_shared.ps1`)

### Changed

- Improved kernel launch configuration (256 threads per block)
- Better error handling in Python bindings

## [0.1.0] — 2025-12-XX

### Added

- Initial CUDA kernel with x⁷ S-box and configurable rounds
- Batch hash API: `poseidon_hash_batch`
- Merkle tree builder: `merkle_build_gpu`
- Python bindings via ctypes
- Basic test suite
- Shared library build (Windows DLL + Linux .so)
