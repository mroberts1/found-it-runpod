## Found It on RunPod: agent notes

Setup for running the "Found It" ComfyUI workflow (Flux.1-dev text-to-image, 4 LoRAs) on RunPod, either on an interactive pod or as a serverless endpoint. For human-facing steps see [README.md](README.md).

Keep this file current: when scripts, paths, versions, or workflow wiring change, update this file and the README in the same change.

## Layout

- `../Found It [ComfyUI workflow] - uisato.json`: the original UI-format workflow. Do not edit it.
- `Found It [RunPod] - uisato.json`: UI-format copy for the pod. Linux LoRA paths (`Flux/...`), `PreviewAny` instead of `show_text_party`, `PrimitiveInt` instead of `Int Literal`.
- `setup.sh`: pod bootstrap. ComfyUI at `/workspace/ComfyUI`, models at `/workspace/ComfyUI/models`.
- `upload_lora.sh`: local rsync of the one LoRA that is not hosted anywhere (`../Experimental_Analog_Photography-FLUX.safetensors`, 2.5GB).
- `serverless/`: `Dockerfile`, `fetch_models.sh`, `workflow_api.json`, `generate.py`.

## Conventions and gotchas

- Models are never committed or baked into the image. Pod and serverless both use a network volume.
- Volume paths differ by mode. Pod: `/workspace`. Serverless worker: `/runpod-volume`, with models expected in `<volume>/models/`, not `<volume>/ComfyUI/models/`.
- LoRA names use forward slashes (`Flux/name.safetensors`). The original workflow uses Windows backslashes and will not match on Linux.
- The VAE file must be named `ae.sft` to match the workflow. It is `ae.safetensors` from the gated FLUX.1-dev repo, renamed on download.
- `flux1-dev` and `ae` need `HF_TOKEN` from an account that accepted the license. Civitai LoRAs need `CIVITAI_TOKEN`. Read both from env vars, never write them into files.
- Civitai LoRAs are fetched by version id (1640450, 1026423, 1135830). 1640450 is 2000s Analog Core v3, saved as `2000sAnalogCore.safetensors` so the workflow name still matches. Check the id if a LoRA filename changes.
- Download helpers skip existing files and resume with `-C -`, so the scripts are safe to re-run.
- `serverless/workflow_api.json` is hand-derived from the UI graph, not exported from ComfyUI. If the UI workflow changes, update it by hand or re-export with "Save (API Format)". Node 85 is the prompt, node 25 the seed.
- `FilmGrain` (node 80) is bypassed in the UI workflow, so the API graph omits it and `SaveImage` reads `VAEDecode`. Re-enabling it means adding `comfyui-post-processing-nodes` to the Dockerfile and `setup.sh`.
- Node pack registry names for `comfy-node-install`: `comfy-mtb`, `comfyui-kjnodes`, `comfyui-post-processing-nodes`.
- The worker base image tag is pinned in `serverless/Dockerfile`. Verify a tag exists on Docker Hub before bumping it (`5.11.0-base` did not exist when `5.10.0-base` was chosen).

## Checks

There is no test suite or linter. Before claiming a change works:

- `bash -n setup.sh upload_lora.sh serverless/fetch_models.sh`
- `python3 -I -m py_compile serverless/generate.py`, then delete the generated `__pycache__`
- `python3 -I -c "import json,sys; [json.load(open(f)) for f in sys.argv[1:]]" *.json serverless/*.json`

None of this has run on a real pod or endpoint yet. Say so rather than reporting the setup as verified.

## Environment

The local volume `/Volumes/Projects` has been low on disk (about 15GB free). Avoid downloading models or building Docker images locally.
