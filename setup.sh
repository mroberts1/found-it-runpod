#!/usr/bin/env bash
# Run on the RunPod pod. Expects the network volume mounted at /workspace and ComfyUI at /workspace/ComfyUI.
# Required env vars (set as RunPod pod secrets or export them first): HF_TOKEN, CIVITAI_TOKEN
# HF_TOKEN must belong to an account that accepted the FLUX.1-dev license.
set -euo pipefail

COMFY="${COMFY:-/workspace/ComfyUI}"
: "${HF_TOKEN:?set HF_TOKEN}"
: "${CIVITAI_TOKEN:?set CIVITAI_TOKEN}"

if [ ! -d "$COMFY" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
  pip install -r "$COMFY/requirements.txt"
fi

# Custom nodes used by the workflow
cd "$COMFY/custom_nodes"
clone() { [ -d "$(basename "$1")" ] || git clone --depth 1 "https://github.com/$1.git"; }
clone melMass/comfy_mtb
clone kijai/ComfyUI-KJNodes
clone EllangoK/ComfyUI-post-processing-nodes
for d in comfy_mtb ComfyUI-KJNodes ComfyUI-post-processing-nodes; do
  [ -f "$d/requirements.txt" ] && pip install -r "$d/requirements.txt" || true
done

# Models. Skips files that already exist, so it is safe to re-run.
M="$COMFY/models"
mkdir -p "$M/unet" "$M/clip" "$M/vae" "$M/loras/Flux"

fetch() { # url dest [auth header]
  [ -s "$2" ] && { echo "have $2"; return; }
  curl -fL --retry 3 -C - ${3:+-H "$3"} -o "$2.part" "$1" && mv "$2.part" "$2"
}
HF="Authorization: Bearer $HF_TOKEN"
fetch https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors "$M/unet/flux1-dev.safetensors" "$HF"
fetch https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors        "$M/vae/ae.sft"                  "$HF"
fetch https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors      "$M/clip/clip_l.safetensors"
fetch https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors  "$M/clip/t5xxl_fp16.safetensors"

# Civitai LoRAs (version ids resolved from the model pages in the workflow notes)
civ() { fetch "https://civitai.com/api/download/models/$1?token=$CIVITAI_TOKEN" "$M/loras/Flux/$2"; }
civ 1276001 2000sAnalogCore.safetensors
civ 1026423 UltraRealPhoto.safetensors
civ 1135830 VHS_flux_v1_000001500.safetensors

[ -s "$M/loras/Flux/Experimental_Analog_Photography-FLUX.safetensors" ] || \
  echo "MISSING: upload Experimental_Analog_Photography-FLUX.safetensors with upload_lora.sh"

echo "Start with: cd $COMFY && python main.py --listen 0.0.0.0 --port 8188"
