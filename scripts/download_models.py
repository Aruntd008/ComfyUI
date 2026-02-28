import os
import sys
import argparse
import requests
from tqdm import tqdm

# Define the models required (matching what was previously in Dockerfile)
MODELS = [
    {
        "url": "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors",
        "path": "clip/t5xxl_fp16.safetensors"
    },
    {
        "url": "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors",
        "path": "clip/clip_l.safetensors"
    },
    {
        "url": "https://huggingface.co/yichengup/flux.1-fill-dev-OneReward/resolve/main/unet_fp16.safetensors",
        "path": "diffusion_models/unet_fp16.safetensors"
    },
    {
        "url": "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/ae.safetensors",
        "path": "vae/ae.safetensors"
    },
    {
        "url": "https://huggingface.co/google/siglip2-so400m-patch16-512/resolve/main/model.safetensors",
        "path": "clip_vision/sglip2-so400m-patch16-512.safetensors"
    },
    {
        "url": "https://huggingface.co/camenduru/FLUX.1-dev/resolve/d616d290809ffe206732ac4665a9ddcdfb839743/flux1-redux-dev.safetensors",
        "path": "style_models/flux1-redux-dev.safetensors"
    },
    {
        "url": "https://huggingface.co/1038lab/sam/resolve/main/sam_vit_l.pth",
        "path": "sams/sam_vit_l.pth", 
    },
    {
        "url": "https://huggingface.co/1038lab/GroundingDINO/resolve/main/GroundingDINO_SwinT_OGC.cfg.py",
        "path": "grounding-dino/GroundingDINO_SwinT_OGC.cfg.py"
    },
    {
        "url": "https://huggingface.co/1038lab/GroundingDINO/resolve/main/groundingdino_swint_ogc.pth",
        "path": "grounding-dino/groundingdino_swint_ogc.pth"
    }
]

def download_file(url, target_path):
    """Download file with progress bar. Skip if fully downloaded based on basic size check."""
    # Ensure directory exists
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    # Try to resume or skip if already downloaded
    response = requests.get(url, stream=True, allow_redirects=True)
    if response.status_code != 200:
        print(f"Error: Failed to fetch {url} (Status Code: {response.status_code})")
        return False
        
    total_size = int(response.headers.get('content-length', 0))
    
    # Simple check: if file exists and has the exact same size, skip
    # For very small text files (like .py, .yml) HuggingFace might compress them so lengths don't match
    if os.path.exists(target_path):
        local_size = os.path.getsize(target_path)
        if total_size > 0 and local_size == total_size:
            print(f"✅ Skipping (already downloaded): {target_path}")
            return True
        elif total_size == 0 and local_size > 0:
            print(f"✅ Skipping (server gave no size, but file exists): {target_path}")
            return True
        elif local_size > 0 and total_size < 100 * 1024: # Smaller than 100KB is likely text/compressed
            print(f"✅ Skipping (small file exists, likely text/compressed): {target_path}")
            return True
        else:
            print(f"⚠️ Partial file found for {target_path}. Local: {local_size}, Remote: {total_size}. Restarting...")
            
    # Download
    print(f"⬇️ Downloading to {target_path}")
    block_size = 1024 * 1024 # 1 Megabyte
    
    try:
        with open(target_path, 'wb') as file, tqdm(
                desc=os.path.basename(target_path),
                total=total_size,
                unit='iB',
                unit_scale=True,
                unit_divisor=1024,
            ) as bar:
            for data in response.iter_content(block_size):
                file.write(data)
                bar.update(len(data))
        return True
    except Exception as e:
        print(f"❌ Error downloading {target_path}: {e}")
        # Clean up partial file
        if os.path.exists(target_path):
            os.remove(target_path)
        return False

def main():
    parser = argparse.ArgumentParser(description="Download ComfyUI Models to Network Storage")
    parser.add_argument("models_dir", help="The base directory where models should be saved (e.g. /runpod-volume/models)")
    args = parser.parse_args()

    models_dir = args.models_dir
    print(f"🚀 Starting model downloads to {models_dir}...")
    
    os.makedirs(models_dir, exist_ok=True)
    
    failed_downloads = []
    
    for model in MODELS:
        target_path = os.path.join(models_dir, model["path"])
        success = download_file(model["url"], target_path)
        if not success:
            failed_downloads.append(model["url"])
            
    if failed_downloads:
        print("\n❌ The following downloads failed:")
        for url in failed_downloads:
            print(f"  - {url}")
        sys.exit(1)
    else:
        print("\n🎉 All models downloaded successfully!")

if __name__ == "__main__":
    main()
