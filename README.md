# Hunyuan3D-2.1 for ComfyUI — ARM64 / CUDA 13

Upload any photo → automatic background removal → textured 3D model → interactive viewer, running locally on ARM64 Linux with CUDA 13 (tested on NVIDIA DGX Spark / GB10 Blackwell).

## Requirements

- ComfyUI installed
- Python 3.12, PyTorch 2.10+, CUDA 13
- aarch64 / ARM64 Linux
- ~16 GB VRAM, ~10 GB disk for models

## Install

```bash
git clone https://github.com/Ligator/hunyuan3d-comfyui-arm64
cd hunyuan3d-comfyui-arm64
chmod +x install.sh
./install.sh /path/to/ComfyUI /path/to/comfyui-env/bin/python
```

That's it. The script installs everything: custom nodes, prebuilt extensions, models (~9 GB), and the workflow.

## Use

1. Restart ComfyUI
2. Open **Workflows → Image_to_3D_with_BgRemoval**
3. Load any photo in the **LoadImage** node
4. Click **Queue Prompt**

Output `.glb` files are saved to `ComfyUI/output/3D/`.

## What it does

```
LoadImage → Remove Background → 3D Shape Generation → Mesh Cleanup
        → Texture Painting → Bake → Textured .glb → Preview3D
```

For a full technical breakdown see [TECHNICAL.md](TECHNICAL.md).

## Models

| Model | Size | Purpose |
|-------|------|---------|
| `hunyuan3d-dit-v2-1-fp16.ckpt` | 6.9 GB | Shape generation (DiT, 3B params) |
| `Hunyuan3D-vae-v2-1-fp16.ckpt` | 626 MB | Mesh VAE decoder |
| `hunyuan3d-paintpbr-v2-1/` | ~1.3 GB | PBR texture painting (1.3B params) |

All models are from [tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1) on HuggingFace. The install script downloads them automatically.

## Credits

- [Tencent Hunyuan3D-2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1) — the model
- [visualbruno/ComfyUI-Hunyuan3d-2-1](https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1) — the ComfyUI wrapper
- [danielgatis/rembg](https://github.com/danielgatis/rembg) — background removal
