# ============================================================
# Stage 1: Builder — installs deps, compiles extensions
# ============================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/root/.local/bin:/opt/venv/bin:${PATH}" \
    UV_PROJECT_ENVIRONMENT="/opt/venv"

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev \
    git curl build-essential cmake ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Create venv
RUN uv venv --python python3.11 /opt/venv

WORKDIR /comfyui

# ---- Dependency cache layer ----
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

# ---- Copy source after deps ----
COPY . .
RUN uv sync --frozen


# ============================================================
# Stage 2: Blender Download (isolated for caching)
# ============================================================
FROM ubuntu:22.04 AS blender

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates aria2 xz-utils \
    && aria2c -x 16 -s 16 \
    https://mirror.freedif.org/blender/release/Blender5.0/blender-5.0.1-linux-x64.tar.xz \
    && tar xf blender-5.0.1-linux-x64.tar.xz \
    && mv blender-5.0.1-linux-x64 /blender \
    && rm blender-5.0.1-linux-x64.tar.xz \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Stage 3: Runtime — lean final image
# ============================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:/opt/blender:${PATH}" \
    # ---- change this if you want to use a different directory for models ----
    MODEL_DIR=/runpod-volume/models \
    COMFYUI_PORT=8188

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    git \
    # ---- Core GL / EGL / DRM stack ----
    libgl1 \
    libgl1-mesa-dri \
    libegl1 \
    libglu1-mesa \
    libdrm2 \
    libgbm1 \
    # ---- X11 stack ----
    libx11-6 \
    libxrender1 \
    libxi6 \
    libxxf86vm1 \
    libxfixes3 \
    libxext6 \
    libxrandr2 \
    libxcursor1 \
    libxinerama1 \
    libxkbcommon-x11-0 \
    libsm6 \
    # ---- Vulkan ----
    mesa-vulkan-drivers \
    mesa-utils \
    # ---- Misc ----
    libglib2.0-0 \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---- Copy Blender from isolated stage ----
COPY --from=blender /blender /opt/blender

# ──── Critical fixes: make blender discoverable everywhere ────
RUN chmod +x /opt/blender/blender && \
    chmod -R 755 /opt/blender && \
    ln -sf /opt/blender/blender /usr/local/bin/blender && \
    ln -sf /opt/blender/blender /usr/bin/blender && \
    ln -sf /opt/blender/blender /bin/blender && \
    echo "Blender symlinks created" && \
    /usr/bin/blender --version || echo "Blender version check failed during build"

# ---- Copy Python env ----
COPY --from=builder /opt/venv /opt/venv

# ---- Copy App ----
COPY --from=builder /comfyui /comfyui

WORKDIR /

COPY handler.py /handler.py
COPY network_volume.py /network_volume.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

EXPOSE 8188

HEALTHCHECK --interval=15s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8188/system_stats || exit 1

CMD ["/start.sh"]