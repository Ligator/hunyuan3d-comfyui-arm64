#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# Hunyuan3D-2.1 ComfyUI setup — ARM64 / CUDA 13
# Usage: ./install.sh <comfyui_path> <python_executable>
#
# Example:
#   ./install.sh /home/user/ComfyUI /home/user/comfyui-env/bin/python
# ─────────────────────────────────────────────────────────────

COMFYUI_DIR="${1:?Usage: ./install.sh <comfyui_path> <python_executable>}"
PYTHON="${2:?Usage: ./install.sh <comfyui_path> <python_executable>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "ComfyUI dir : $COMFYUI_DIR"
echo "Python      : $PYTHON"
echo ""

# ── 1. ComfyUI-Hunyuan3d-2-1 custom node ──────────────────────
echo "[1/6] Installing ComfyUI-Hunyuan3d-2-1..."
NODE_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI-Hunyuan3d-2-1"
if [ ! -d "$NODE_DIR" ]; then
    git clone https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1 "$NODE_DIR"
else
    echo "      Already cloned, pulling latest..."
    git -C "$NODE_DIR" pull
fi
"$PYTHON" -m pip install -q -r "$NODE_DIR/requirements.txt"

# ── 2. Prebuilt C++ extensions ─────────────────────────────────
echo "[2/6] Installing prebuilt wheels (custom_rasterizer + mesh_inpaint_processor)..."
"$PYTHON" -m pip install -q \
    "$SCRIPT_DIR/wheels/custom_rasterizer-0.1-cp312-cp312-linux_aarch64.whl" \
    "$SCRIPT_DIR/wheels/mesh_inpaint_processor-0.0.0-cp312-cp312-linux_aarch64.whl"

# ── 3. KJNodes ─────────────────────────────────────────────────
echo "[3/6] Installing ComfyUI-KJNodes..."
KJ_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI-KJNodes"
if [ ! -d "$KJ_DIR" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes "$KJ_DIR"
else
    echo "      Already cloned, pulling latest..."
    git -C "$KJ_DIR" pull
fi
"$PYTHON" -m pip install -q -r "$KJ_DIR/requirements.txt"

# ── 4. Background removal node ─────────────────────────────────
echo "[4/6] Installing background removal node..."
"$PYTHON" -m pip install -q rembg
cp "$SCRIPT_DIR/comfyui_rembg_simple.py" "$COMFYUI_DIR/custom_nodes/"

# ── 5. Download models ─────────────────────────────────────────
echo "[5/6] Downloading models from HuggingFace (~9 GB total)..."

DIT_DEST="$COMFYUI_DIR/models/diffusion_models/hunyuan3d-dit-v2-1-fp16.ckpt"
VAE_DEST="$COMFYUI_DIR/models/vae/Hunyuan3D-vae-v2-1-fp16.ckpt"

"$PYTHON" - <<EOF
import huggingface_hub, shutil, os

dit = "$DIT_DEST"
vae = "$VAE_DEST"

if not os.path.exists(dit):
    print("  Downloading DiT shape model (6.9 GB)...")
    f = huggingface_hub.hf_hub_download(
        repo_id="tencent/Hunyuan3D-2.1",
        filename="hunyuan3d-dit-v2-1/model.fp16.ckpt",
        local_dir="/tmp/hy3d_dl"
    )
    shutil.move(f, dit)
    print(f"  Saved: {dit}")
else:
    print(f"  DiT model already exists, skipping.")

if not os.path.exists(vae):
    print("  Downloading VAE model (626 MB)...")
    f = huggingface_hub.hf_hub_download(
        repo_id="tencent/Hunyuan3D-2.1",
        filename="hunyuan3d-vae-v2-1/model.fp16.ckpt",
        local_dir="/tmp/hy3d_dl"
    )
    shutil.move(f, vae)
    print(f"  Saved: {vae}")
else:
    print(f"  VAE model already exists, skipping.")

print("  Downloading paint model (1.3 GB)...")
huggingface_hub.snapshot_download(
    repo_id="tencent/Hunyuan3D-2.1",
    allow_patterns=["hunyuan3d-paintpbr-v2-1/*"],
)
print("  Paint model cached.")
EOF

# ── 6. Copy workflow ───────────────────────────────────────────
echo "[6/6] Installing workflow..."
WORKFLOW_DIR="$COMFYUI_DIR/user/default/workflows"
mkdir -p "$WORKFLOW_DIR"
cp "$SCRIPT_DIR/Image_to_3D_with_BgRemoval.json" "$WORKFLOW_DIR/"

echo ""
echo "✓ Done! Restart ComfyUI and open the workflow:"
echo "  Workflows menu → Image_to_3D_with_BgRemoval"
echo ""
