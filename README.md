## Found It on RunPod

Scripts and a patched copy of the "Found It" ComfyUI workflow (Flux.1-dev text-to-image with four LoRAs) for RunPod. Two ways to run it: an interactive pod (this section) or a serverless endpoint (see the Serverless section). Notes for coding agents are in [AGENTS.md](AGENTS.md).

## Files

- `Found It [RunPod] - uisato.json`: the workflow with Linux LoRA paths (`Flux/...`), `show_text_party` replaced by core `PreviewAny`, and the two `Int Literal` nodes (not found in any of the installed packs) replaced by core `PrimitiveInt`. The original workflow one folder up is untouched.
- `setup.sh`: run on the pod. Installs ComfyUI, the custom nodes, and downloads the models and Civitai LoRAs. Safe to re-run, it skips files that exist.
- `upload_lora.sh`: run locally. Copies `Experimental_Analog_Photography-FLUX.safetensors` (not hosted anywhere) to the pod.

## Requirements

- A RunPod network volume of at least 60GB, mounted at `/workspace`. Models total about 40GB.
- A GPU with 48GB (A6000, L40S) for headroom. 24GB works with offloading but is slower.
- `HF_TOKEN` from a Hugging Face account that accepted the FLUX.1-dev license. `flux1-dev` and `ae` are gated.
- `CIVITAI_TOKEN` for the three Civitai LoRAs.

## Steps

1. Deploy a PyTorch pod with the network volume attached. Expose TCP for SSH and HTTP port 8188.
2. On the pod:

   ```
   export HF_TOKEN=... CIVITAI_TOKEN=...
   bash setup.sh
   ```

3. Locally, after step 2 finishes. The IP and port come from the pod's SSH over exposed TCP details:

   ```
   ./upload_lora.sh <pod-ip> <ssh-port>
   ```

4. On the pod:

   ```
   cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188
   ```

5. Open the pod's port 8188 proxy URL and load `Found It [RunPod] - uisato.json`.

## What gets installed

Custom nodes (cloned into `ComfyUI/custom_nodes`):

- `melMass/comfy_mtb`
- `kijai/ComfyUI-KJNodes`
- `EllangoK/ComfyUI-post-processing-nodes`

Models (under `ComfyUI/models`):

| Path                                                | Source                                       |
| --------------------------------------------------- | -------------------------------------------- |
| `unet/flux1-dev.safetensors`                        | black-forest-labs/FLUX.1-dev                 |
| `vae/ae.sft`                                        | `ae.safetensors` from FLUX.1-dev, renamed    |
| `clip/clip_l.safetensors`                           | comfyanonymous/flux_text_encoders            |
| `clip/t5xxl_fp16.safetensors`                       | comfyanonymous/flux_text_encoders            |
| `loras/Flux/2000sAnalogCore.safetensors`            | Civitai version 1640450 (v3, renamed)         |
| `loras/Flux/UltraRealPhoto.safetensors`             | Civitai version 1026423                      |
| `loras/Flux/VHS_flux_v1_000001500.safetensors`      | Civitai version 1135830                      |
| `loras/Flux/Experimental_Analog_Photography-FLUX.safetensors` | `upload_lora.sh`                   |

## Known gaps

- Not yet tested on a pod. The scripts are only syntax-checked.
- `PrimitiveInt` was written by hand into the saved format, so reconnect or resize it if it looks off on load.
- `PreviewAny` needs a recent ComfyUI. The setup script clones the latest, so a fresh pod is fine.
- The `ae.sft` source differs from the workflow notes, which link the FLUX.1-schnell copy. Check that the VAE output looks right.

## Serverless

An endpoint built on `runpod/worker-comfyui`, with models on the network volume and only the custom nodes baked into the image. It takes an API-format workflow, so it uses `serverless/workflow_api.json` instead of the UI JSON.

Files in `serverless/`:

- `Dockerfile`: `runpod/worker-comfyui:5.10.0-base` plus `comfy-mtb` and `comfyui-kjnodes`. `FilmGrain` is bypassed in the workflow, so `post-processing-nodes` is left out.
- `fetch_models.sh`: run on a pod with the volume attached. Downloads the same models as `setup.sh`, but into `/workspace/models`, which the worker sees as `/runpod-volume/models`.
- `workflow_api.json`: the graph in API format. Node 85 holds the prompt and node 25 the seed. Width and height are 1024 by 1344, taken from the old `Int Literal` values.
- `generate.py`: calls `/runsync` with a prompt and saves the returned images.

Steps:

1. Create a network volume (60GB or more). Attach it to a cheap pod, then run `HF_TOKEN=... CIVITAI_TOKEN=... bash fetch_models.sh`.
2. Upload the Experimental Analog Photography LoRA to `/workspace/models/loras/Flux/`. `upload_lora.sh` targets the interactive pod layout, so change its destination path.
3. Build the image. Either push the `serverless/` folder to a GitHub repo and use "Start from GitHub Repo" when creating the endpoint, or build locally with `docker buildx build --platform linux/amd64 --push -t <you>/found-it-worker:1 serverless/`. The GitHub route avoids local disk use.
4. Create the endpoint: select the image, attach the network volume under Advanced, and pick a 48GB GPU. Set the container disk for a base image of a few GB.
5. Generate:

   ```
   export RUNPOD_API_KEY=... ENDPOINT_ID=...
   serverless/generate.py "a doorway in dark water, silhouette" --out out
   ```

Sharing one volume with the interactive pod: if `setup.sh` already put models in `/workspace/ComfyUI/models`, run `ln -s ComfyUI/models /workspace/models` on a pod. The link must be relative so it resolves under `/runpod-volume`.

Serverless known gaps:

- Untested. The shell and Python files are only syntax-checked, and the API graph was written by hand from the UI graph and the node sources, not exported from ComfyUI.
- `5.10.0-base` is the newest `-base` tag I could confirm on Docker Hub. The repo's latest release is 5.11.0, but its `-base` tag returned 404.
- Cold starts load about 40GB of weights from the volume, so the first request after idle will be slow, and `/runsync` can time out. Use `/run` plus polling if it does.
