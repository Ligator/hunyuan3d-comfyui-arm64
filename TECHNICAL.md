# Technical Notes

## Why ARM64 needs special handling

The [ComfyUI-Hunyuan3d-2-1](https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1) wrapper includes two C++ extensions that handle mesh rasterization and texture inpainting. The upstream repo only ships prebuilt wheels for Windows and Linux x86_64 — nothing for aarch64. On top of that, CUDA 13 (required for the GB10 Blackwell GPU) adds another constraint since most wheels target CUDA 12.x.

The wheels in `wheels/` were compiled on a DGX Spark (GB10, compute 12.1) with:
- Python 3.12
- CUDA 13.0
- PyTorch 2.10.0+cu130
- Ubuntu 24.04, aarch64

### custom_rasterizer
A CUDA extension (`CUDAExtension`) that provides GPU-accelerated mesh rasterization used during texture baking. Compiled with `TORCH_CUDA_ARCH_LIST="12.1"`.

### mesh_inpaint_processor
A C++ pybind11 extension used to fill in texture gaps on the mesh after multi-view baking.

If you need to recompile for a different Python or CUDA version:
```bash
# custom_rasterizer
cd ComfyUI/custom_nodes/ComfyUI-Hunyuan3d-2-1/hy3dpaint/custom_rasterizer
TORCH_CUDA_ARCH_LIST="<your_compute>" python setup.py install

# mesh_inpaint_processor
cd ../DifferentiableRenderer
python setup.py install
```

---

## Using the Workflow

1. Restart ComfyUI after running `install.sh`
2. Open ComfyUI → click the **Workflows** menu → load **Image_to_3D_with_BgRemoval**
3. In the **LoadImage** node, select your input photo
4. Click **Queue Prompt**

### Pipeline overview

```
LoadImage
   └─► SimpleRemBG (rembg U2Net)         ← auto bg removal, outputs RGBA
          ├─► Hy3DMeshGenerator           ← 3B DiT model, 25-step diffusion
          │      └─► Hy3D21VAEDecode      ← marching cubes at octree res 256
          │             └─► PostprocessMesh (cleanup, 200k face limit)
          │                    ├─► Hy3D21ExportMesh → 3D/Hy3D_shape_*.glb
          │                    └─► Hy3D21MeshUVWrap (xatlas unwrap)
          │                           └─► Hy3DMultiViewsGenerator  ← 6-view PBR paint
          │                                  └─► Hy3DBakeMultiViews → Hy3DInPaint
          │                                         └─► Hy21_Mesh_*.glb + Preview3D
          └─► Hy3DMultiViewsGenerator (reference RGBA for texture conditioning)
```

Output files saved to `ComfyUI/output/`:
- `3D/Hy21_Mesh_*.glb` — fully textured 3D model with PBR materials
- `3D/Hy3D_shape_*.glb` — untextured shape only (intermediate output)

---

## Pipeline breakdown

### 1. Background removal (`comfyui_rembg_simple.py`)
A minimal ComfyUI node wrapping the [`rembg`](https://github.com/danielgatis/rembg) library (U2Net model). Takes any RGB image, returns an RGBA image with the background set to transparent. The Hunyuan3D pipeline uses the alpha channel to center and crop the object before feeding it to the shape model.

### 2. Shape generation (`Hy3DMeshGenerator`)
Runs the Hunyuan3D-DiT-v2-1 model (3B parameters, fp16, 6.9 GB). A flow-matching diffusion transformer conditioned on the input RGBA image via a DINOv2 image encoder. Produces a latent shape representation over 25 steps.

### 3. VAE decode (`Hy3D21VAEDecode`)
Decodes the latent shape into an explicit triangle mesh using marching cubes at octree resolution 256. The ShapeVAE has a separate encoder/decoder for the 3D geometry.

### 4. Mesh cleanup (`Hy3D21PostprocessMesh`)
Removes floating fragments, degenerate faces, and optionally reduces the face count (set to 200k here).

### 5. UV unwrapping (`Hy3D21MeshUVWrap`)
Unwraps the mesh using [xatlas](https://github.com/jpcy/xatlas) to generate UV coordinates needed for texture baking.

### 6. Texture generation (`Hy3DMultiViewsGenerator`)
Runs the HunyuanPaint pipeline (1.3B parameters, `hunyuan3d-paintpbr-v2-1`) — a multi-view diffusion model conditioned on the reference RGBA image. Renders 6 views of the mesh from different angles and generates albedo + metallic/roughness (PBR) maps for each. The paint model is downloaded automatically from HuggingFace on first run (~1.3 GB).

### 7. Baking and inpainting (`Hy3DBakeMultiViews` + `Hy3DInPaint`)
Projects the multi-view renders onto the UV map, fills any uncoated regions via inpainting, and saves the final textured mesh as a `.glb` file with PBR materials.

### 8. Preview (`Preview3D`)
ComfyUI's built-in 3D viewer renders the `.glb` interactively inside the browser.

---

## Models

| Model | File | Size | Source |
|-------|------|------|--------|
| DiT shape model | `diffusion_models/hunyuan3d-dit-v2-1-fp16.ckpt` | 6.9 GB | [tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1) |
| VAE decoder | `vae/Hunyuan3D-vae-v2-1-fp16.ckpt` | 626 MB | [tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1) |
| Paint model | HuggingFace cache (auto) | ~1.3 GB | [tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1) |

---

## Credits

- [Tencent Hunyuan3D-2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1) — the model
- [visualbruno/ComfyUI-Hunyuan3d-2-1](https://github.com/visualbruno/ComfyUI-Hunyuan3d-2-1) — the ComfyUI wrapper
- [danielgatis/rembg](https://github.com/danielgatis/rembg) — background removal
