"""
Simple background removal node for ComfyUI using rembg.
Provides RGBA output compatible with Hunyuan3D-2.1 pipeline.
"""
import torch
import numpy as np
from PIL import Image
from rembg import remove, new_session


class SimpleRemBG:
    _session = None

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),
            }
        }

    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("image_rgba",)
    FUNCTION = "remove_bg"
    CATEGORY = "image/preprocessing"

    def remove_bg(self, image):
        if SimpleRemBG._session is None:
            SimpleRemBG._session = new_session("u2net")

        results = []
        for img_tensor in image:
            # [H, W, 3] float tensor → uint8 PIL Image
            img_np = (img_tensor.cpu().numpy() * 255).clip(0, 255).astype(np.uint8)
            if img_np.shape[-1] == 4:
                img_pil = Image.fromarray(img_np, "RGBA")
            else:
                img_pil = Image.fromarray(img_np, "RGB")

            # Remove background → RGBA with transparent background
            img_rgba = remove(img_pil, session=SimpleRemBG._session)
            if img_rgba.mode != "RGBA":
                img_rgba = img_rgba.convert("RGBA")

            # Convert back to float tensor [H, W, 4]
            img_rgba_np = np.array(img_rgba).astype(np.float32) / 255.0
            results.append(torch.from_numpy(img_rgba_np))

        return (torch.stack(results),)


NODE_CLASS_MAPPINGS = {
    "SimpleRemBG": SimpleRemBG,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "SimpleRemBG": "Remove Background (rembg)",
}
