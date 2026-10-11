FROM runpod/worker-comfyui:5.10.0-base

# Models live on the network volume (see fetch_models.sh), only custom nodes are baked in.
RUN comfy-node-install comfy-mtb comfyui-kjnodes
