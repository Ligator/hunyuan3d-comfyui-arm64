# Hunyuan3D-2.1 in ComfyUI — ARM64 / CUDA 13 Setup

A complete guide and workflow for running **Hunyuan3D-2.1** (image → textured 3D mesh) inside ComfyUI on **ARM64 Linux with CUDA 13** (tested on NVIDIA DGX Spark / GB10 Blackwell, compute 12.1).

Includes:
- Step-by-step ARM64 setup guide (compiling C++ extensions from source)
- `comfyui_rembg_simple.py` — a minimal background removal node
- `Image_to_3D_with_BgRemoval.json` — a ready-to-use workflow

**No TRELLIS2** — it's blocked on CUDA 13 / aarch64 by `spconv` and `o_voxel` build failures. Hunyuan3D-2.1 works fully.

---

## Result

Upload any photo → automatic background removal → 3D mesh with PBR textures → interactive viewer.

<img src="https://huggingface.co/tencent/Hunyuan3D-2.1/resolve/main/assets/teaser.png" alt="Hunyuan3D-2.1 examples" />

---

## System Requirements

| Component | Requirement |
|-----------|-------------|
| GPU | NVIDIA with CUDA 13, compute 12.x (e.g. GB10 Blackwell) |
| CPU arch | aarch64 / ARM64 |
| VRAM | ~16 GB for full shape + texture pipeline |
| RAM | 16 GB+ |
| Python | 3.12 |
| PyTorch | 2.10+ with CUDA 13 |
| OS | Linux (Ubuntu 24.04 tested) |

---

## Setup

### 1. Install the ComfyUI-Hunyuan3d-2-1 custom node

```bash
cd ComfyUI/custom_nodes
git clone https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1
```

Install Python dependencies (use your ComfyUI Python env):

```bash
/path/to/comfyui-env/bin/pip install -r ComfyUI-Hunyuan3d-2-1/requirements.txt
```

### 2. Compile the C++ extensions from source

No prebuilt aarch64 wheels exist. You must compile both extensions. Make sure `nvcc` and `g++` are available.

**custom_rasterizer** (CUDA extension):

```bash
cd ComfyUI/custom_nodes/ComfyUI-Hunyuan3d-2-1/hy3dpaint/custom_rasterizer
TORCH_CUDA_ARCH_LIST="12.1" /path/to/comfyui-env/bin/python setup.py install
```

> Replace `12.1` with your GPU's compute capability. For GB10 Blackwell it is `12.1`.

**mesh_inpaint_processor** (C++ pybind11 extension):

```bash
/path/to/comfyui-env/bin/python \
  ComfyUI/custom_nodes/ComfyUI-Hunyuan3d-2-1/hy3dpaint/DifferentiableRenderer/setup.py install
```

Verify both load correctly (torch must be imported first):

```bash
/path/to/comfyui-env/bin/python -c "import torch; import custom_rasterizer; import mesh_inpaint_processor; print('OK')"
```

### 3. Download the models

```bash
/path/to/comfyui-env/bin/python - << 'EOF'
import huggingface_hub, os, shutil

# DiT shape model → diffusion_models/
f = huggingface_hub.hf_hub_download(
    repo_id="tencent/Hunyuan3D-2.1",
    filename="hunyuan3d-dit-v2-1/model.fp16.ckpt",
    local_dir="/tmp/hy3d"
)
dest = "ComfyUI/models/diffusion_models/hunyuan3d-dit-v2-1-fp16.ckpt"
shutil.move(f, dest)
print("DiT model:", dest)

# VAE decoder → vae/
f = huggingface_hub.hf_hub_download(
    repo_id="tencent/Hunyuan3D-2.1",
    filename="hunyuan3d-vae-v2-1/model.fp16.ckpt",
    local_dir="/tmp/hy3d"
)
dest = "ComfyUI/models/vae/Hunyuan3D-vae-v2-1-fp16.ckpt"
shutil.move(f, dest)
print("VAE model:", dest)

# Pre-cache the paint model (auto-downloaded on first run otherwise)
huggingface_hub.snapshot_download(
    repo_id="tencent/Hunyuan3D-2.1",
    allow_patterns=["hunyuan3d-paintpbr-v2-1/*"],
)
print("Paint model cached.")
EOF
```

### 4. Install KJNodes (for utility nodes)

```bash
cd ComfyUI/custom_nodes
git clone https://github.com/kijai/ComfyUI-KJNodes
/path/to/comfyui-env/bin/pip install -r ComfyUI-KJNodes/requirements.txt
```

### 5. Install the background removal node

Copy `comfyui_rembg_simple.py` from this repo into your `ComfyUI/custom_nodes/` directory:

```bash
cp comfyui_rembg_simple.py ComfyUI/custom_nodes/
```

Make sure `rembg` is installed:

```bash
/path/to/comfyui-env/bin/pip install rembg
```

### 6. Restart ComfyUI

```bash
# If running as a systemd service, killing the process lets it auto-restart:
kill $(pgrep -f "python.*main.py")
```

---

## Using the Workflow

1. Copy `Image_to_3D_with_BgRemoval.json` into `ComfyUI/user/default/workflows/`
2. Open ComfyUI → click the Workflows menu → load **Image_to_3D_with_BgRemoval**
3. In the **LoadImage** node, select your input photo
4. Click **Queue Prompt**

### Pipeline overview

```
LoadImage
   └─► Remove Background (rembg)     ← auto bg removal, outputs RGBA
          ├─► Hy3DMeshGenerator       ← 3B DiT model, generates 3D shape
          │      └─► Hy3D21VAEDecode  ← decodes latents to triangle mesh
          │             └─► PostprocessMesh → MeshUVWrap
          │                    ├─► ExportMesh (.glb, untextured)
          │                    └─► MultiViewsGenerator  ← paints textures
          │                           └─► BakeMultiViews → InPaint
          │                                  └─► output_glb_path
          └─► MultiViewsGenerator (reference image for painting)
                                        └─► Preview3D  ← interactive viewer
```

**Output files** are saved to `ComfyUI/output/3D/`:
- `Hy21_Mesh_*.glb` — fully textured 3D model (PBR materials)
- `3D/Hy3D_shape_*.glb` — untextured shape only

---

## Troubleshooting

**`ImportError: libc10.so: cannot open shared object file`**
This happens when importing `custom_rasterizer` without torch loaded first. Inside ComfyUI this is not an issue. If testing manually, always `import torch` first.

**`RuntimeError: CUDA error: no kernel image is available`**
Wrong compute capability. Check your GPU's SM version and set `TORCH_CUDA_ARCH_LIST` accordingly (e.g. `"12.1"` for GB10, `"8.9"` for RTX 4090).

**Shape generates but texture step fails / hangs**
The paint model (`hunyuan3d-paintpbr-v2-1`) downloads ~1.3 GB on first run. Be patient or pre-download it (see step 3 above).

**TRELLIS2 / spconv errors**
TRELLIS2 requires `spconv` and `o_voxel`, neither of which compile on CUDA 13 + Blackwell aarch64 as of early 2026. Use Hunyuan3D-2.1 instead.

---

## Models

All models are from Tencent's [tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1) on HuggingFace.

| Model | Size | Purpose |
|-------|------|---------|
| `hunyuan3d-dit-v2-1-fp16.ckpt` | 6.9 GB | Shape generation (DiT, 3B params) |
| `Hunyuan3D-vae-v2-1-fp16.ckpt` | 626 MB | Mesh VAE decoder |
| `hunyuan3d-paintpbr-v2-1/` | ~1.3 GB | PBR texture painting (1.3B params) |

---

## Credits

- [Tencent Hunyuan3D-2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1) — the model
- [visualbruno/ComfyUI-Hunyuan3d-2-1](https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1) — the ComfyUI wrapper
- [danielgatis/rembg](https://github.com/danielgatis/rembg) — background removal
