#!/bin/bash
set -e

cd /workspace

# Basic tools
apt-get update && apt-get install -y curl git git-lfs wget

# Require HF token from environment
if [ -z "$HF_TOKEN" ]; then
  echo "ERROR: HF_TOKEN environment variable is not set."
  exit 1
fi

# Clone ComfyUI only once if it doesn't exist yet
if [ ! -d "ComfyUI" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git
fi

cd ComfyUI

# Make sure pip is recent
pip install --upgrade pip

# Use torch build that matches the CUDA 12.x image (no cu118 index!)
# This upgrades to a recent GPU-capable build for Blackwell.
pip install "torch>=2.3.1" "torchvision>=0.18.0" "torchaudio>=2.3.0"

# ComfyUI base requirements
pip install -r requirements.txt

# Pixtral + numpy compatibility
pip install "transformers==4.53.3" "numpy<2.0"

# --------------------------------------------------------------------
# Custom nodes (clone only if missing)
# --------------------------------------------------------------------
cd custom_nodes

for repo in \
  "https://github.com/ltdrdata/ComfyUI-Manager.git" \
  "https://github.com/rgthree/rgthree-comfy.git" \
  "https://github.com/cubiq/ComfyUI_essentials.git" \
  "https://github.com/crystian/ComfyUI-Crystools.git" \
  "https://github.com/WASasquatch/was-node-suite-comfyui.git" \
  "https://github.com/bmad4ever/comfyui_bmad_nodes.git" \
  "https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet.git" \
  "https://github.com/yolain/ComfyUI-Easy-Use.git" \
  "https://github.com/theUpsider/ComfyUI-Logic.git" \
  "https://github.com/giriss/comfy-image-saver.git"
do
  name=$(basename "$repo" .git)
  if [ ! -d "$name" ]; then
    git clone "$repo"
  fi
done

# Node-specific requirements
cd ComfyUI_essentials && pip install -r requirements.txt && cd ..
cd ComfyUI-Crystools && pip install -r requirements.txt && cd ..
cd was-node-suite-comfyui && pip install -r requirements.txt && cd ..
cd ComfyUI-Easy-Use && pip install -r requirements.txt && cd ..

cd /workspace/ComfyUI

# --------------------------------------------------------------------
# Model downloads (same as A100 script)
# --------------------------------------------------------------------

if [ ! -f models/diffusion_models/flux2-dev.safetensors ]; then
  curl -L --create-dirs \
    -H "Authorization: Bearer $HF_TOKEN" \
    -o models/diffusion_models/flux2-dev.safetensors \
    "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/flux2-dev.safetensors"
fi

if [ ! -f models/text_encoders/mistral_small_flux2_fp8.safetensors ]; then
  curl -L --create-dirs \
    -o models/text_encoders/mistral_small_flux2_fp8.safetensors \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors"
fi

if [ ! -f models/loras/HerbstPhoto_v4_Flux2.safetensors ]; then
  curl -L --create-dirs \
    -H "Authorization: Bearer $HF_TOKEN" \
    -o models/loras/HerbstPhoto_v4_Flux2.safetensors \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_v4_Flux2.safetensors"
fi

if [ ! -f models/vae/flux2-vae.safetensors ]; then
  curl -L --create-dirs \
    -o models/vae/flux2-vae.safetensors \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"
fi

mkdir -p input
if [ ! -f input/ImageToImagePlaceHolder.png ]; then
  wget -O input/ImageToImagePlaceHolder.png \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/ImageToImagePlaceHolder.png"
fi

mkdir -p user/default/workflows
if [ ! -f user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json ]; then
  wget -O user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_Flux2_ComfyUI_Workflow_v02.json"
fi

# --------------------------------------------------------------------
# Launch ComfyUI (GPU, assuming CUDA 12.x image supports Blackwell)
# --------------------------------------------------------------------
python main.py --listen 0.0.0.0 --port 8188
