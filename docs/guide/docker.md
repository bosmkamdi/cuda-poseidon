# Docker

## Pre-built Images

Images are published to GitHub Container Registry (GHCR) on every release:

```bash
# Pull latest
docker pull ghcr.io/bosmkamdi/cuda-poseidon:latest

# Pull specific version
docker pull ghcr.io/bosmkamdi/cuda-poseidon:0.2.0
```

## Running

### Runtime (C/C++ applications)

```bash
docker run --rm --gpus all \
  -v $(pwd)/data:/data \
  ghcr.io/bosmkamdi/cuda-poseidon:latest
```

### Python

```bash
docker run --rm --gpus all \
  ghcr.io/bosmkamdi/cuda-poseidon:python \
  python3 /opt/poseidon/poseidon_py.py
```

### Run Tests Inside Container

```bash
docker run --rm --gpus all \
  ghcr.io/bosmkamdi/cuda-poseidon:builder \
  /src/test_poseidon
```

## Building Locally

```bash
# Build all targets
docker buildx bake

# Build specific target
docker build --target runtime --tag poseidon:local .
docker build --target python --tag poseidon:python .

# Run
docker run --rm --gpus all poseidon:local
```

### docker-compose

```bash
# GPU must be available
docker compose up cuda-poseidon
docker compose run cuda-poseidon-test
```

## Image Variants

| Tag                | Size    | Contents                          |
|--------------------|---------|-----------------------------------|
| `latest`           | ~1.2 GB | Runtime only (library + header)   |
| `python`           | ~1.4 GB | Runtime + Python bindings         |
| `builder` (target) | ~8 GB   | Build env (tests, source, toolkit)|

!!! warning "GPU Access Required"

    All run commands require the NVIDIA Container Toolkit and `--gpus all` flag.
    [Install NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

## Using as a Base Image

```dockerfile
FROM ghcr.io/bosmkamdi/cuda-poseidon:latest AS poseidon

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04
COPY --from=poseidon /opt/poseidon /opt/poseidon
ENV LD_LIBRARY_PATH=/opt/poseidon:${LD_LIBRARY_PATH}

# Your application here
COPY myapp /app/
RUN gcc -o /app/myapp /app/myapp.c -L/opt/poseidon -I/opt/poseidon -lposeidon_cuda
CMD ["/app/myapp"]
```
