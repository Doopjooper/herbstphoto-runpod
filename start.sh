#!/bin/bash
set -e

cd /workspace && \
apt-get update && apt-get install -y curl git git-lfs wget && \
git clone https://github.com/comfyanonymous/ComfyUI.git && \
cd ComfyUI && \
pip install -r requirements.txt && \
cd custom_nodes && \
git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
git clone https://github.com/rgthree/rgthree-comfy.git && \
git clone https://github.com/cubiq/ComfyUI_essentials.git && \
git clone https://github.com/crystian/ComfyUI-Crystools.git && \
git clone https://github.com/WASasquatch/was-node-suite-comfyui.git && \
git clone https://github.com/bmad4ever/comfyui_bmad_nodes.git && \
git clone https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet.git && \
git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
git clone https://github.com/theUpsider/ComfyUI-Logic.git && \
git clone https://github.com/giriss/comfy-image-saver.git && \
cd ComfyUI_essentials && pip install -r requirements.txt && cd .. && \
cd ComfyUI-Crystools && pip install -r requirements.txt && cd .. && \
cd was-node-suite-comfyui && pip install -r requirements.txt && cd .. && \
cd ComfyUI-Easy-Use && pip install -r requirements.txt && cd .. && \
cd /workspace/ComfyUI && \
git config --global credential.helper store && \
echo "https://user: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@huggingface.co" > ~/.git-credentials && \
curl -L -o models/diffusion_models/flux2-dev.safetensors --create-dirs --header "Authorization: Bearer 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" "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/flux2-dev.safetensors" && \
curl -L -o models/text_encoders/mistral_small_flux2_fp8.safetensors --create-dirs "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors" && \
curl -L -o models/loras/HerbstPhoto_v4_Flux2.safetensors --create-dirs --header "Authorization: Bearer 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" "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_v4_Flux2.safetensors" && \
curl -L -o models/vae/ae.safetensors --create-dirs --header "Authorization: Bearer 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" "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/vae/diffusion_pytorch_model.safetensors" && \
mkdir -p input && \
wget -O input/ImageToImagePlaceHolder.png "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/ImageToImagePlaceHolder.png" && \
mkdir -p user/default/workflows && \
wget -O user/default/workflows/HerbstPhoto_Flux2_ComfyUI_Workflow.json "https://huggingface.co/CalvinHerbst/HerbstPhoto_v4_Flux2/resolve/main/HerbstPhoto_Flux2_ComfyUI_Workflow_v02.json" && \
python main.py --listen 0.0.0.0 --port 8188