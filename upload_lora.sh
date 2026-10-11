#!/usr/bin/env bash
# Run locally. Usage: ./upload_lora.sh <pod-ip> <ssh-port>   (from the pod's "Connect > SSH over exposed TCP")
set -euo pipefail
HOST="${1:?pod ip}"; PORT="${2:?ssh port}"
SRC="$(dirname "$0")/../Experimental_Analog_Photography-FLUX.safetensors"
ssh -p "$PORT" "root@$HOST" 'mkdir -p /workspace/ComfyUI/models/loras/Flux'
rsync -avP --partial -e "ssh -p $PORT" "$SRC" "root@$HOST:/workspace/ComfyUI/models/loras/Flux/"
