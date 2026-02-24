# ============================================================
# Furnish - RunPod Serverless ComfyUI Worker
# CUDA 12.8 (Blackwell Compatible)
# Fully Pinned via uv.lock
# Models mounted via /runpod-volume
# ============================================================

FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_PREFER_BINARY=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
ENV MODEL_DIR=/runpod-volume/models
ENV COMFYUI_PORT=8188
ENV PIP_NO_INPUT=1

# ------------------------------------------------------------
# Install Minimal System Dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    git \
    curl \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    libgoogle-perftools4 \
    ca-certificates \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Install uv
# ------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ------------------------------------------------------------
# Create Virtual Environment (Build Time Only)
# ------------------------------------------------------------
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# ------------------------------------------------------------
# Setup Workdir & Install Dependencies (Caching Layer)
# ------------------------------------------------------------
WORKDIR /comfyui

# ------------------------------------------------------------
# Download FLUX Models (Individually Cached Layers)
# ------------------------------------------------------------
RUN mkdir -p models/clip models/diffusion_models models/vae models/clip_vision models/style_models models/SAM models/grounding-dino

# FLUX Text Encoders
RUN wget -q -O models/clip/t5xxl_fp16.safetensors "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
RUN wget -q -O models/clip/clip_l.safetensors "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors"

# FLUX UNet Diffusion Model
RUN wget -q -O models/diffusion_models/unet_fp16.safetensors "https://huggingface.co/yichengup/flux.1-fill-dev-OneReward/resolve/main/unet_fp16.safetensors"

# VAE Model
RUN wget -q -O models/vae/ae.safetensors "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/ae.safetensors"

# CLIP Vision Model (SigLIP)
RUN wget -q -O models/clip_vision/sglip2-so400m-patch16-512.safetensors "https://huggingface.co/google/siglip2-so400m-patch16-512/resolve/main/model.safetensors"

# Style Model (FLUX Redux)
RUN wget -q -O models/style_models/flux1-redux-dev.safetensors "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/flux1-redux-dev.safetensors"

# SegmentV2 Models (SAM & GroundingDINO)
RUN wget -q -O models/SAM/sam_vit_l.pth "https://huggingface.co/1038lab/sam/resolve/main/sam_vit_l.pth"
RUN wget -q -O models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py "https://huggingface.co/1038lab/GroundingDINO/resolve/main/GroundingDINO_SwinT_OGC.cfg.py"
RUN wget -q -O models/grounding-dino/groundingdino_swint_ogc.pth "https://huggingface.co/1038lab/GroundingDINO/resolve/main/groundingdino_swint_ogc.pth"

# ------------------------------------------------------------
# Install Python Dependencies
# ------------------------------------------------------------
# Copy dependency files first to leverage Docker layer caching
COPY pyproject.toml uv.lock /comfyui/

# Install dependencies before copying source code to speed up rebuilds
RUN uv sync --frozen --no-install-project

# ------------------------------------------------------------
# Copy Your ComfyUI Fork
# ------------------------------------------------------------
COPY . /comfyui/

# Final sync to install the project code itself
RUN uv sync --frozen

# ------------------------------------------------------------
# Install RunPod SDK + minimal runtime deps
# ------------------------------------------------------------
RUN uv add runpod requests websocket-client

# ------------------------------------------------------------
# Copy Handler and Startup Script
# ------------------------------------------------------------
WORKDIR /
COPY handler.py /handler.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ------------------------------------------------------------
# Setup ComfyUI Manager network mode
# ------------------------------------------------------------
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# ------------------------------------------------------------
# Expose ComfyUI internal port
# ------------------------------------------------------------
EXPOSE 8188

# ------------------------------------------------------------
# Start Container
# ------------------------------------------------------------
CMD ["/start.sh"]