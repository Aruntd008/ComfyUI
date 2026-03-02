#!/usr/bin/env bash
set -e

echo "============================================"
echo "Starting Furnish ComfyUI Worker (Baked Models)"
echo "============================================"

# ------------------------------------------------------------
# Use TCMalloc for better GPU memory behavior
# ------------------------------------------------------------
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
if [ -n "$TCMALLOC" ]; then
    export LD_PRELOAD="${TCMALLOC}"
    echo "Using TCMalloc: $TCMALLOC"
fi

# ------------------------------------------------------------
# Ensure ComfyUI-Manager runs in offline network mode
# ------------------------------------------------------------
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

# ------------------------------------------------------------
# Models are baked into /comfyui/models — no network volume,
# no extra_model_paths.yaml needed (ComfyUI finds models at
# its default location automatically).
# ------------------------------------------------------------
: "${COMFYUI_PORT:=8188}"
echo "Models directory: /comfyui/models"
echo "Listing baked model types:"
ls /comfyui/models/ 2>/dev/null || echo "(models dir not found — check Dockerfile build)"

# ------------------------------------------------------------
# Start ComfyUI and RunPod Handler
# ------------------------------------------------------------
echo "worker-comfyui: Starting ComfyUI"
: "${COMFY_LOG_LEVEL:=DEBUG}"

if [ "${SERVE_API_LOCALLY:=false}" = "true" ]; then
    PYTHONUNBUFFERED=1 /opt/venv/bin/python -u /comfyui/main.py \
        --disable-auto-launch --disable-metadata \
        --listen 0.0.0.0 --port ${COMFYUI_PORT} \
        --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    PYTHONUNBUFFERED=1 /opt/venv/bin/python -u /handler.py \
        --rp_serve_api --rp_api_host=0.0.0.0
else
    PYTHONUNBUFFERED=1 /opt/venv/bin/python -u /comfyui/main.py \
        --disable-auto-launch --disable-metadata \
        --port ${COMFYUI_PORT} \
        --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    PYTHONUNBUFFERED=1 /opt/venv/bin/python -u /handler.py
fi
