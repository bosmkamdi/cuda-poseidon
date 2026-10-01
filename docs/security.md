# Security Policy

## Reporting a Vulnerability

Please do not open GitHub issues for security vulnerabilities.

Instead, email: **bosmkamdi@gmail.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Suggested fix (optional)

We aim to respond within 48 hours and will release patches as soon as possible.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | ✅ Yes     |
| 0.1.x   | ⚠️ Critical fixes only |

## Known Security Considerations

- **Timing side-channels**: The CUDA kernel uses constant-time modular arithmetic but may leak timing information across warps on shared GPUs.
- **Memory remnants**: GPU buffers are not zeroed after use. Sensitive data (private keys in field form) may persist in VRAM.
- **32-bit prime limitation**: The simplified prime is not cryptographically suitable for production ZK applications. See the v2 branch for full-width field arithmetic.
