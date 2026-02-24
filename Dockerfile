# ============================================================
# Stage 1: Builder — installs deps, compiles extensions
# ============================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/root/.local/bin:/opt/venv/bin:${PATH}"

# Build-only deps (won't appear in final image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev \
    git curl build-essential cmake ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN uv venv /opt/venv

WORKDIR /comfyui

# Cache dependency install layer separately from source code
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

COPY . /comfyui/
RUN uv sync --frozen


# ============================================================
# Stage 2: Model Downloader — parallel downloads, own cache layer
# ============================================================
FROM ubuntu:22.04 AS model-downloader

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /models

RUN mkdir -p clip diffusion_models vae clip_vision style_models SAM grounding-dino

# Each model is its own layer — only re-downloads when URL changes
# FLUX Text Encoders
RUN wget -q --show-progress -O clip/t5xxl_fp16.safetensors \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"

RUN wget -q --show-progress -O clip/clip_l.safetensors \
    "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors"

# FLUX UNet
RUN wget -q --show-progress -O diffusion_models/unet_fp16.safetensors \
    "https://huggingface.co/yichengup/flux.1-fill-dev-OneReward/resolve/main/unet_fp16.safetensors"

# VAE
RUN wget -q --show-progress -O vae/ae.safetensors \
    "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/ae.safetensors"

# CLIP Vision
RUN wget -q --show-progress -O clip_vision/sglip2-so400m-patch16-512.safetensors \
    "https://huggingface.co/google/siglip2-so400m-patch16-512/resolve/main/model.safetensors"

# Style Model
RUN wget -q --show-progress -O style_models/flux1-redux-dev.safetensors \
    "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/flux1-redux-dev.safetensors"

# SAM
RUN wget -q --show-progress -O SAM/sam_vit_l.pth \
    "https://huggingface.co/1038lab/sam/resolve/main/sam_vit_l.pth"

# GroundingDINO
RUN wget -q --show-progress -O grounding-dino/GroundingDINO_SwinT_OGC.cfg.py \
    "https://huggingface.co/1038lab/GroundingDINO/resolve/main/GroundingDINO_SwinT_OGC.cfg.py"

RUN wget -q --show-progress -O grounding-dino/groundingdino_swint_ogc.pth \
    "https://huggingface.co/1038lab/GroundingDINO/resolve/main/groundingdino_swint_ogc.pth"


# ============================================================
# Stage 3: Runtime — lean final image
# ============================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:${PATH}" \
    MODEL_DIR=/comfyui/models \
    COMFYUI_PORT=8188

# Runtime-only system deps — no dev headers, no build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    ffmpeg libgoogle-perftools4 ca-certificates curl \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy venv from builder (no pip/uv needed at runtime)
COPY --from=builder /opt/venv /opt/venv

# Copy app source from builder
COPY --from=builder /comfyui /comfyui

# Copy models from model-downloader stage
COPY --from=model-downloader /models /comfyui/models

WORKDIR /
COPY handler.py /handler.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

EXPOSE 8188

HEALTHCHECK --interval=15s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8188/system_stats || exit 1

CMD ["/start.sh"]