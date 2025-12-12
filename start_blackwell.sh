#!/bin/bash
set -euo pipefail

cd /workspace

apt-get update && apt-get install -y curl git git-lfs wget
if [ -z "${HF_TOKEN:-}" ]; then
  echo "ERROR: HF_TOKEN environment variable is not set."
  exit 1
fi

if [ ! -d "ComfyUI" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git
fi
cd ComfyUI

pip install --upgrade pip
pip install --index-url https://download.pytorch.org/whl/cu118 \
  "torch==2.3.1" "torchvision==0.18.1" "torchaudio==2.3.1"
pip install -r requirements.txt
pip install "transformers==4.53.3" "numpy<2.0"

# Jupyter on 8888
if ! command -v jupyter >/dev/null 2>&1; then
  pip install -U jupyterlab ipykernel
fi
jupyter lab --ip 0.0.0.0 --port 8888 --no-browser --allow-root \
  --ServerApp.token='' --ServerApp.password='' \
  --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True >/workspace/jupyter.log 2>&1 &

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
  if [ ! -d "$name" ]; then git clone "$repo"; fi
done

cd ComfyUI_essentials && pip install -r requirements.txt && cd ..
cd ComfyUI-Crystools && pip install -r requirements.txt && cd ..
cd was-node-suite-comfyui && pip install -r requirements.txt && cd ..
cd ComfyUI-Easy-Use && pip install -r requirements.txt && cd ..

cd /workspace/ComfyUI

download() {
  local url="$1" out="$2" auth="${3:-0}" min_bytes="${4:-1048576}"
  mkdir -p "$(dirname "$out")"
  local tmp="${out}.part"
  rm -f "$tmp"

  if [ "$auth" = "1" ]; then
    curl -fL --retry 6 --retry-all-errors --retry-delay 2 \
      -H "Authorization: Bearer $HF_TOKEN" \
      -o "$tmp" "$url"
  else
    curl -fL --retry 6 --retry-all-errors --retry-delay 2 \
      -o "$tmp" "$url"
  fi

  local sz
  sz=$(stat -c%s "$tmp" 2>/dev/null || echo 0)
  if [ "$sz" -lt "$min_bytes" ]; then
    echo "ERROR: Download too small ($sz bytes) for $out. Usually token/license (403) saved as HTML."
    head -c 200 "$tmp" || true
    exit 1
  fi
  mv "$tmp" "$out"
}

# Flux2-dev (needs accepted license + valid HF_TOKEN)
[ -f models/diffusion_models/flux2-dev.safetensors ] || \
  download "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/flux2-dev.safetensors" \
           "models/diffusion_models/flux2-dev.safetensors" 1 1000000000

# Text encoder (public)
[ -f models/text_encoders/mistral_small_flux2_fp8.safetensors ] || \
  download "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors" \
           "models/text_encoders/mistral_small_flux2_fp8.safetensors" 0 1000000

# HerbstPhoto LoRA (private to your repo)
[ -f models/loras/HerbstPhoto_v4_Flux2.safetensors ] || \
  download "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_v4_Flux2.safetensors" \
           "models/loras/HerbstPhoto_v4_Flux2.safetensors" 1 1000000

# VAE (use Comfy-Org split to avoid “wrong file” / partial downloads)
[ -f models/vae/flux2-vae.safetensors ] || \
  download "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
           "models/vae/flux2-vae.safetensors" 0 1000000

mkdir -p input
[ -f input/ImageToImagePlaceHolder.png ] || \
  wget -O input/ImageToImagePlaceHolder.png \
  "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/ImageToImagePlaceHolder.png"

mkdir -p user/default/workflows
[ -f user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json ] || \
  wget -O user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json \
  "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_Flux2_ComfyUI_Workflow_v02.json"

python main.py --listen 0.0.0.0 --port 8188
