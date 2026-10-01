# syntax=docker/dockerfile:1
# ============================================================
# cuda-poseidon — Multi-stage Dockerfile
# Stage 1: CUDA toolkit build environment
# Stage 2: Lightweight runtime image (library only)
# Target: linux/amd64
# ============================================================

# ── Stage 1: Build ──────────────────────────────────────────
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Cache layer: copy only build-relevant files
COPY poseidon_cuda.cu poseidon_cuda.h poseidon_cuda.def ./
COPY test_poseidon.c build_shared.py* ./

# Build shared library with full optimizations
RUN nvcc -O3 --use_fast_math \
    -gencode arch=compute_70,code=sm_70 \
    -gencode arch=compute_75,code=sm_75 \
    -gencode arch=compute_80,code=sm_80 \
    -gencode arch=compute_86,code=sm_86 \
    -gencode arch=compute_89,code=sm_89 \
    -gencode arch=compute_90,code=sm_90 \
    --shared -o libposeidon_cuda.so poseidon_cuda.cu -Xcompiler -fPIC

# Build and run tests as part of image build (fails fast on regression)
RUN nvcc -O3 -o test_poseidon test_poseidon.c poseidon_cuda.cu && \
    /src/test_poseidon

# ── Stage 2: Runtime library image ──────────────────────────
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

LABEL maintainer="bosmkamdi@gmail.com"
LABEL description="CUDA Poseidon Hash — GPU-accelerated ZK hash library"
LABEL org.opencontainers.image.source="https://github.com/bosmkamdi/cuda-poseidon"

WORKDIR /opt/poseidon

# Copy shared library and header from builder
COPY --from=builder /src/libposeidon_cuda.so /opt/poseidon/
COPY --from=builder /src/poseidon_cuda.h /opt/poseidon/
COPY --from=builder /src/poseidon_cuda.cu /opt/poseidon/

# Set library path so downstream images can link
ENV LD_LIBRARY_PATH=/opt/poseidon:${LD_LIBRARY_PATH}
ENV POSEIDON_HOME=/opt/poseidon

# Non-root user
RUN useradd -m -s /bin/bash poseidon
USER poseidon

# Default command: print library info
CMD ["sh", "-c", "echo 'cuda-poseidon library ready:' && ls -lh ${POSEIDON_HOME}/"]

# ── Stage 3: Python bindings image ──────────────────────────
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS python

LABEL description="CUDA Poseidon Hash with Python bindings"

WORKDIR /opt/poseidon

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/libposeidon_cuda.so /opt/poseidon/
COPY poseidon_py.py /opt/poseidon/
COPY --from=builder /src/poseidon_cuda.cu /opt/poseidon/
COPY --from=builder /src/poseidon_cuda.h /opt/poseidon/

ENV LD_LIBRARY_PATH=/opt/poseidon:${LD_LIBRARY_PATH}
RUN useradd -m -s /bin/bash poseidon
USER poseidon

CMD ["python3", "/opt/poseidon/poseidon_py.py"]
