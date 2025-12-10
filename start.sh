#!/bin/bash
set -e

# Require a Hugging Face token from the environment
if [ -z "$HF_TOKEN" ]; then
  echo "ERROR: HF_TOKEN environment variable is not set."
  echo "Set HF_TOKEN to a Hugging Face read token in your RunPod template."
  exit 1
fi

cd /workspace

apt-get update && apt-get install -y curl git git-lfs wget

# Clone ComfyUI
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Base requirements
pip install -r requirements.txt

# Custom nodes
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/cubiq/ComfyUI_essentials.git
git clone https://github.com/crystian/ComfyUI-Crystools.git
git clone https://github.com/WASasquatch/was-node-suite-comfyui.git
git clone https://github.com/bmad4ever/comfyui_bmad_nodes.git
git clone https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet.git
git clone https://github.com/yolain/ComfyUI-Easy-Use.git
git clone https://github.com/theUpsider/ComfyUI-Logic.git
git clone https://github.com/giriss/comfy-image-saver.git

# Custom-node requirements
cd ComfyUI_essentials && pip install -r requirements.txt && cd ..
cd ComfyUI-Crystools && pip install -r requirements.txt && cd ..
cd was-node-suite-comfyui && pip install -r requirements.txt && cd ..
cd ComfyUI-Easy-Use && pip install -r requirements.txt && cd ..

cd /workspace/ComfyUI

# -------------------------
# Models from Hugging Face
# -------------------------

# FLUX.2-dev UNet
curl -L --create-dirs \
  -H "Authorization: Bearer ${HF_TOKEN}" \
  -o models/diffusion_models/flux2-dev.safetensors \
  "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/flux2-dev.safetensors"

# Flux2 text encoder
curl -L --create-dirs \
  -H "Authorization: Bearer ${HF_TOKEN}" \
  -o models/text_encoders/mistral_small_flux2_fp8.safetensors \
  "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors"

# HerbstPhoto LoRA
curl -L --create-dirs \
  -H "Authorization: Bearer ${HF_TOKEN}" \
  -o models/loras/HerbstPhoto_v4_Flux2.safetensors \
  "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_v4_Flux2.safetensors"

# Correct Flux2 VAE for Comfy
curl -L --create-dirs \
  -H "Authorization: Bearer ${HF_TOKEN}" \
  -o models/vae/flux2-vae.safetensors \
  "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"

# Input placeholder
mkdir -p input
wget --header="Authorization: Bearer ${HF_TOKEN}" \
  -O input/ImageToImagePlaceHolder.png \
  "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/ImageToImagePlaceHolder.png"

# Default workflow
mkdir -p user/default/workflows
wget --header="Authorization: Bearer ${HF_TOKEN}" \
  -O user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json \
  "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_Flux2_ComfyUI_Workflow_v02.json"

# -------------------------
# Dependency fixes
# -------------------------

# Numpy <2 for binary compatibility, recent transformers for Pixtral
pip install --no-cache-dir "numpy<2.0" "transformers==4.53.3"

# -------------------------
# Launch ComfyUI
# -------------------------

python main.py --listen 0.0.0.0 --port 8188
