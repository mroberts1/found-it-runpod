#!/usr/bin/env bash
# Run on a pod with the network volume mounted at /workspace.
# Serverless workers see the same volume at /runpod-volume, with models expected in <volume>/models/.
# Required env vars: HF_TOKEN (account that accepted the FLUX.1-dev license), CIVITAI_TOKEN
set -euo pipefail

: "${HF_TOKEN:?set HF_TOKEN}"
: "${CIVITAI_TOKEN:?set CIVITAI_TOKEN}"
M="${MODELS:-/workspace/models}"
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

civ() { fetch "https://civitai.com/api/download/models/$1?token=$CIVITAI_TOKEN" "$M/loras/Flux/$2"; }
civ 1640450 2000sAnalogCore.safetensors  # v3 (2000analogcore_v3.safetensors), saved under the name the workflow expects
civ 1026423 UltraRealPhoto.safetensors
civ 1135830 VHS_flux_v1_000001500.safetensors

[ -s "$M/loras/Flux/Experimental_Analog_Photography-FLUX.safetensors" ] || \
  echo "MISSING: upload Experimental_Analog_Photography-FLUX.safetensors to $M/loras/Flux/ (see ../upload_lora.sh, change the destination)"
