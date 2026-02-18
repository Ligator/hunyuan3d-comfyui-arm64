#!/usr/bin/env python3
"""
Patch ComfyUI-Hunyuan3d-2-1/nodes.py to use folder_paths API for output
and temp directories instead of hardcoded paths derived from the node's
location. This ensures correct behaviour regardless of which ComfyUI
instance is running (e.g. a second instance with output_2/ instead of output/).
"""
import sys

REPLACEMENTS = [
    # Longer/more-specific patterns first to avoid partial matches
    (
        'os.path.join(comfy_path, "temp", f"{output_file_name}.obj")',
        'os.path.join(folder_paths.get_temp_directory(), f"{output_file_name}.obj")',
    ),
    (
        'os.path.join(comfy_path, "output", f"{output_mesh_name}.glb")',
        'os.path.join(folder_paths.get_output_directory(), f"{output_mesh_name}.glb")',
    ),
    (
        'os.path.join(comfy_path, "output", "3D", output_name)',
        'os.path.join(folder_paths.get_output_directory(), "3D", output_name)',
    ),
    (
        'os.path.join(comfy_path, "output", "3D", output_mesh_name)',
        'os.path.join(folder_paths.get_output_directory(), "3D", output_mesh_name)',
    ),
    (
        'os.path.join(comfy_path, "temp")',
        'folder_paths.get_temp_directory()',
    ),
]

def main():
    filepath = sys.argv[1]
    with open(filepath) as f:
        content = f.read()

    total = 0
    for old, new in REPLACEMENTS:
        count = content.count(old)
        if count:
            content = content.replace(old, new)
            print(f"  {count}x: {old[:60]}")
            total += count

    if total == 0:
        print("  Nothing to patch (already applied or upstream changed).")
    else:
        with open(filepath, "w") as f:
            f.write(content)
        print(f"  {total} replacements applied.")

if __name__ == "__main__":
    main()
