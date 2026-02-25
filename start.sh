#!/usr/bin/env bash
set -e

echo "============================================"
echo "Starting Furnish Serverless ComfyUI Worker"
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
# Ensure model mount exists and setup ComfyUI paths config
# ------------------------------------------------------------
: "${MODEL_DIR:=/runpod-volume/models}"
: "${COMFYUI_PORT:=8188}"

mkdir -p "${MODEL_DIR}"
echo "Models mounted at: ${MODEL_DIR}"

# ComfyUI dynamically loads extra models using an extra_model_paths.yaml config file
cat <<EOF > /comfyui/extra_model_paths.yaml
runpod_volume:
    base_path: ${MODEL_DIR}
    checkpoints: checkpoints
    configs: configs
    loras: loras
    vae: vae
    clip: clip
    unet: unet
    ultralytics: ultralytics
    segment_anything: segment_anything
    controlnet: controlnet
    style_models: style_models
    embeddings: embeddings
    diffusers: diffusers
    clip_vision: clip_vision
    gligen: gligen
    upscale_models: upscale_models
    custom_nodes: custom_nodes
    sams: sams
    facelandmark: facelandmark
    pulid: pulid
    insightface: insightface
EOF

# ------------------------------------------------------------
# Start ComfyUI (Background)
# ------------------------------------------------------------
echo "Launching ComfyUI..."
: "${COMFY_LOG_LEVEL:=DEBUG}"

/opt/venv/bin/python -u /comfyui/main.py \
    --disable-auto-launch \
    --disable-metadata \
    --listen 0.0.0.0 \
    --port ${COMFYUI_PORT} \
    --verbose "${COMFY_LOG_LEVEL}" \
    --log-stdout &

COMFY_PID=$!
echo "ComfyUI started with PID ${COMFY_PID}"

# Small wait to ensure ComfyUI is ready
sleep 5

# ------------------------------------------------------------
# Start RunPod Handler (Foreground)
# ------------------------------------------------------------
echo "Launching RunPod handler..."

if [ "$SERVE_API_LOCALLY" == "true" ]; then
    /opt/venv/bin/python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    /opt/venv/bin/python -u /handler.py
fi
