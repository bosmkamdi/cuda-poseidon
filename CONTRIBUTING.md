# Contributing to cuda-poseidon

Thank you for your interest in contributing! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

- Check if the issue already exists
- Open a new issue with a clear title and description
- Include steps to reproduce, expected behavior, and actual behavior
- Attach relevant logs, screenshots, or test cases

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests to ensure nothing is broken
5. Commit with clear, descriptive messages
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Coding Standards

- **C/CUDA**: Follow the existing style (K&R indentation, descriptive variable names)
- **Python**: Follow PEP 8, use type hints
- **Comments**: Document complex algorithms and GPU-specific optimizations
- **Tests**: Add tests for new features

### Commit Message Convention

```
feat: add support for BLS12-381 field
fix: correct round constant generation for t=8
docs: update API reference for merkle_tree_hash
test: add edge-case tests for empty input
refactor: optimize memory access pattern in kernel
perf: reduce shared memory bank conflicts
```

## Development Setup

```bash
git clone https://github.com/bosmkamdi/cuda-poseidon.git
cd cuda-poseidon
# Build with your preferred method
./build_shared.ps1
```

## Code of Conduct

Be respectful and constructive in all interactions.
