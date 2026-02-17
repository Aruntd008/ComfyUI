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
uv sync

# Install ComfyUI Manager
git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/comfyui-manager

# Start ComfyUI
uv run python main.py
```

Now use the **Manager GUI** to install all your custom nodes.

---

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
```
