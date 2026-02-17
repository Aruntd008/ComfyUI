# ComfyUI Deployment Guide

Complete guide to set up a reproducible ComfyUI environment with custom nodes, deployable to RunPod.

---

## Phase 1: Fork & Clone

### On GitHub
1. Go to https://github.com/Comfy-Org/ComfyUI
2. Click **Fork** → creates `Aruntd008/ComfyUI`

### Locally
```bash
cd ~/Projects
git clone https://github.com/Aruntd008/ComfyUI.git
cd ComfyUI

# Add upstream to track original repo (for future upgrades)
git remote add upstream https://github.com/Comfy-Org/ComfyUI.git
```

---

## Phase 2: Set Up Environment & Install Nodes

```bash
# Create venv and install base deps
uv python pin 3.11
uv venv
source .venv/bin/activate
```

Updated pyproject.toml (CUDA 13 / Blackwell Ready)

Replace your file with this:
```toml
[project]
name = "ComfyUI"
version = "0.14.0"
readme = "README.md"
license = { file = "LICENSE" }
requires-python = "==3.11.*"

dependencies = [
    # --- Core ML stack (CUDA 13 / Blackwell compatible) ---
    "torch>=2.7.0",
    "torchvision",
    "torchaudio",

    # Optional performance (can remove if lock fails)
    "xformers",

    # HF stack aligned with modern ComfyUI
    "transformers>=5.0.0",

    # Common runtime deps some nodes expect
    "setuptools",
    "opencv-contrib-python",
]

[project.urls]
homepage = "https://www.comfy.org/"
repository = "https://github.com/comfyanonymous/ComfyUI"
documentation = "https://docs.comfy.org/"

# ---- CUDA 13 index ----
[[tool.uv.index]]
name = "pytorch-cu130"
url = "https://download.pytorch.org/whl/cu130"

[tool.uv.sources]
torch = { index = "pytorch-cu130" }
torchvision = { index = "pytorch-cu130" }
torchaudio = { index = "pytorch-cu130" }
xformers = { index = "pytorch-cu130" }

# ---- Lint config unchanged ----
[tool.ruff]
lint.select = [
  "N805",
  "S307",
  "S102",
  "E",
  "T",
  "W",
  "F",
]

lint.ignore = ["E501", "E722", "E731", "E712", "E402", "E741"]
exclude = ["*.ipynb", "**/generated/*.pyi"]

[tool.pylint]
master.py-version = "3.11"
master.extension-pkg-allow-list = [
  "pydantic",
]
reports.output-format = "colorized"
similarities.ignore-imports = "yes"
messages_control.disable = [
  "missing-module-docstring",
  "missing-class-docstring",
  "missing-function-docstring",
  "line-too-long",
  "too-few-public-methods",
  "too-many-public-methods",
  "too-many-instance-attributes",
  "too-many-positional-arguments",
  "broad-exception-raised",
  "too-many-lines",
  "invalid-name",
  "unused-argument",
  "broad-exception-caught",
  "consider-using-with",
  "fixme",
  "too-many-statements",
  "too-many-branches",
  "too-many-locals",
  "too-many-arguments",
  "too-many-return-statements",
  "too-many-nested-blocks",
  "duplicate-code",
  "abstract-method",
  "superfluous-parens",
  "arguments-differ",
  "redefined-builtin",
  "unnecessary-lambda",
  "dangerous-default-value",
  "invalid-overridden-method",
  "bad-classmethod-argument",
  "wrong-import-order",
  "ungrouped-imports",
  "unnecessary-pass",
  "unnecessary-lambda-assignment",
  "no-else-return",
  "unused-variable",
]
```

```bash
uv lock
uv sync --frozen
git add -f uv.lock

uv add -r requirements.txt
uv lock
uv sync --frozen
```

# Install ComfyUI Manager
```bash
git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/comfyui-manager
uv add -r ./custom_nodes/comfyui-manager/requirements.txt
uv lock && uv sync --frozen
```

# Start ComfyUI
```bash
uv run python main.py
```

# Clone all your custom nodes.
```bash
cd custom_nodes
git clone https://github.com/Aruntd008/comfyui_document_scanner.git
git clone https://github.com/Aruntd008/ComfyUI_SeamlessPattern.git
git clone https://github.com/Aruntd008/ComfyUI_blender_render.git

python ./comfyui-manager/cm-cli.py install \
  ComfyUI-Easy-Use \
  ComfyUI-Inpaint-CropAndStitch \
  ComfyUI-KJNodes \
  ComfyUI-RMBG \
  ComfyUI-TiledDiffusion \
  ComfyUI_AdvancedRefluxControl \
  ComfyUI_Comfyroll_CustomNodes \
  ComfyUI_LayerStyle \
  ComfyUI_essentials \
  rgthree-comfy \
  was-node-suite-comfyui \
  --no-deps


python ./comfyui-manager/cm-cli.py install ComfyUI-Easy-Use@1.3.6 --no-deps
python ./comfyui-manager/cm-cli.py install ComfyUI-Inpaint-CropAndStitch@3.0.7 --no-deps
python ./comfyui-manager/cm-cli.py install ComfyUI-KJNodes@1.2.9 --no-deps
python ./comfyui-manager/cm-cli.py install ComfyUI-RMBG@3.0.0 --no-deps
python ./comfyui-manager/cm-cli.py install ComfyUI_LayerStyle@1.0.90 --no-deps
python ./comfyui-manager/cm-cli.py install ComfyUI_essentials@1.1.0 --no-deps

cd ~/Projects/ComfyUI
git clone https://github.com/yolain/ComfyUI-Easy-Use custom_nodes/ComfyUI-Easy-Use
git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch custom_nodes/ComfyUI-Inpaint-CropAndStitch
git clone https://github.com/kijai/ComfyUI-KJNodes custom_nodes/ComfyUI-KJNodes
git clone https://github.com/1038lab/ComfyUI-RMBG custom_nodes/ComfyUI-RMBG
git clone https://github.com/chflame163/ComfyUI_LayerStyle custom_nodes/ComfyUI_LayerStyle
git clone https://github.com/cubiq/ComfyUI_essentials custom_nodes/ComfyUI_essentials
``` 

---
<!-- 


## Phase 3: Bake Node Dependencies into `pyproject.toml`

This ensures `uv.lock` contains ALL dependencies (ComfyUI + every node).

### Interactive Script

Run this from the ComfyUI root. It processes each node one at a time:

```bash
for dir in custom_nodes/*/; do
    req="$dir/requirements.txt"
    [ ! -f "$req" ] && continue
    node=$(basename "$dir")
    [ "$node" = "__pycache__" ] && continue

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Node: $node"
    echo "Contents:"
    grep -v '^\s*$\|^\s*#' "$req" | sed 's/^/  /'
    echo ""
    read -p "[a]dd / [s]kip / [q]uit? " choice

    case "$choice" in
        a|A) uv add -r "$req" || echo "⚠ FAILED — fix manually with: uv add <pkg>" ;;
        s|S) echo "Skipped" ;;
        q|Q) break ;;
    esac
done
```

> **On failure**: Run `uv add <package>` individually to debug which package is the problem. You can modify version constraints or skip packages that conflict.

---

## Phase 4: Save Snapshot & Commit

```bash
# Save custom node snapshot (records git URLs + commit hashes)
python custom_nodes/comfyui-manager/cm-cli.py save-snapshot --output snapshot.json

# Stage everything
git add -f uv.lock
git add snapshot.json pyproject.toml

# Commit
git commit -m "Add snapshot and baked dependencies"

# Push to your fork
git push -u origin main
```

---

## Phase 5: RunPod Deployment

Use this as your **RunPod startup script**:

```bash
#!/bin/bash
set -e
cd /workspace

# 1. Clone your fork
if [ ! -d "ComfyUI" ]; then
    git clone https://github.com/Aruntd008/ComfyUI.git
fi
cd ComfyUI

# 2. Install all Python deps from uv.lock
uv sync

# 3. Bootstrap Manager
if [ ! -d "custom_nodes/comfyui-manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/comfyui-manager
fi

# 4. Restore nodes (clones repos only, no pip — deps already installed by uv sync)
python custom_nodes/comfyui-manager/cm-cli.py restore-snapshot snapshot.json

# 5. Start
uv run python main.py --listen 0.0.0.0
```

---

## Maintenance

### Upgrading ComfyUI
```bash
git fetch upstream
git merge upstream/main
# Resolve conflicts in pyproject.toml if any
uv sync
git push origin main
```

### Adding a New Node
```bash
# 1. Install via Manager GUI

# 2. Add its deps
uv add -r custom_nodes/<new-node>/requirements.txt

# 3. Save updated snapshot
python custom_nodes/comfyui-manager/cm-cli.py save-snapshot --output snapshot.json

# 4. Commit & push
git add -f uv.lock snapshot.json pyproject.toml
git commit -m "Add <new-node>"
git push
```  -->
