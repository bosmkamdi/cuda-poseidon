# Installation

## Supported Platforms

| Platform | Architecture | CUDA Version | Status |
|----------|-------------|-------------|--------|
| Linux    | x86_64      | 11.0 – 12.6 | ✅ Supported |
| Windows  | x86_64      | 11.0 – 12.6 | ✅ Supported |
| macOS    | —           | —           | ❌ No NVIDIA GPU |

## GPU Requirements

| GPU Architecture | Compute Capability | Examples |
|------------------|-------------------|----------|
| Hopper           | sm_90             | H100, H200 |
| Ada Lovelace     | sm_89             | RTX 4090, RTX 4080 |
| Ampere           | sm_86, sm_80      | A100, RTX 3090, A6000 |
| Turing           | sm_75             | RTX 2080 Ti, T4 |
| Volta            | sm_70             | V100 |
| Pascal           | sm_60, sm_61      | GTX 1080 Ti, P100 |

## Install CUDA Toolkit

=== "Ubuntu/Debian"

    ```bash
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-12-4
    ```

=== "Windows"

    Download from [NVIDIA CUDA Toolkit Archives](https://developer.nvidia.com/cuda-toolkit-archive).

    Ensure `nvcc.exe` is in your `PATH`:
    ```
    C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin
    ```

## Verify Installation

```bash
nvcc --version
nvidia-smi
```

## Install Python (Optional)

```bash
python3 --version  # 3.8+
pip install --upgrade pip
```
