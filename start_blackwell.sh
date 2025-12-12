#!/bin/bash
set -euo pipefail

cd /workspace

apt-get update
apt-get install -y --no-install-recommends curl git git-lfs wget ca-certificates
update-ca-certificates || true

if [ -z "${HF_TOKEN:-}" ]; then
  echo "ERROR: HF_TOKEN environment variable is not set."
  exit 1
fi

if [ ! -d "ComfyUI" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git
fi
cd /workspace/ComfyUI

python -m pip install --upgrade pip

# Torch for CUDA 12.4 (Blackwell-friendly wheels)
python -m pip install --index-url https://download.pytorch.org/whl/cu124 \
  "torch==2.4.0" "torchvision==0.19.0" "torchaudio==2.4.0"

python -m pip install -r requirements.txt
python -m pip install "transformers==4.53.3" "numpy<2.0" --upgrade

cd /workspace/ComfyUI/custom_nodes
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

cd /workspace/ComfyUI/custom_nodes/ComfyUI_essentials && python -m pip install -r requirements.txt
cd /workspace/ComfyUI/custom_nodes/ComfyUI-Crystools && python -m pip install -r requirements.txt
cd /workspace/ComfyUI/custom_nodes/was-node-suite-comfyui && python -m pip install -r requirements.txt
cd /workspace/ComfyUI/custom_nodes/ComfyUI-Easy-Use && python -m pip install -r requirements.txt

cd /workspace/ComfyUI

validate_safetensors () {
  python - <<'PY' "$1"
import sys
from safetensors.torch import safe_open
p=sys.argv[1]
with safe_open(p, framework="pt", device="cpu") as f:
    _ = list(f.keys())
PY
}

hf_download () {
  local url="$1"
  local out="$2"
  local auth="${3:-0}"

  mkdir -p "$(dirname "$out")"
  local tmp="${out}.part"

  local headers=()
  if [ "$auth" = "1" ]; then
    headers=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi

  curl -fL --retry 10 --retry-all-errors --connect-timeout 20 \
    -C - "${headers[@]}" -o "$tmp" "$url"

  mv -f "$tmp" "$out"

  if ! validate_safetensors "$out"; then
    echo "ERROR: Corrupt safetensors: $out (deleting)"
    rm -f "$out"
    return 1
  fi
}

if [ ! -f models/diffusion_models/flux2-dev.safetensors ]; then
  hf_download \
    "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/flux2-dev.safetensors" \
    "models/diffusion_models/flux2-dev.safetensors" \
    1
fi

if [ ! -f models/text_encoders/mistral_small_flux2_fp8.safetensors ]; then
  hf_download \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors" \
    "models/text_encoders/mistral_small_flux2_fp8.safetensors" \
    0
fi

if [ ! -f models/loras/HerbstPhoto_v4_Flux2.safetensors ]; then
  hf_download \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_v4_Flux2.safetensors" \
    "models/loras/HerbstPhoto_v4_Flux2.safetensors" \
    1
fi

if [ ! -f models/vae/flux2-vae.safetensors ]; then
  hf_download \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "models/vae/flux2-vae.safetensors" \
    0
fi
ln -sf /workspace/ComfyUI/models/vae/flux2-vae.safetensors /workspace/ComfyUI/models/vae/ae.safetensors

mkdir -p input
if [ ! -f input/ImageToImagePlaceHolder.png ]; then
  wget -q -O input/ImageToImagePlaceHolder.png \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/ImageToImagePlaceHolder.png"
fi

mkdir -p user/default/workflows
if [ ! -f user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json ]; then
  wget -q -O user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json \
    "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_Flux2_ComfyUI_Workflow_v02.json"
fi

python -m pip install --upgrade jupyterlab ipykernel >/dev/null 2>&1 || true
nohup jupyter lab \
  --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
  --ServerApp.token='' --ServerApp.password='' \
  --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True \
  --ServerApp.root_dir=/workspace \
  > /workspace/jupyter.log 2>&1 &

python main.py --listen 0.0.0.0 --port 8188
