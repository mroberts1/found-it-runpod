#!/usr/bin/env python3
"""Call the RunPod endpoint with workflow_api.json and save the images.

Usage: RUNPOD_API_KEY=... ENDPOINT_ID=... ./generate.py "your prompt" [--seed N] [--out DIR]
"""
import argparse, base64, json, os, random, urllib.request
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("prompt")
ap.add_argument("--seed", type=int, default=random.randint(0, 2**50))
ap.add_argument("--out", default="out")
args = ap.parse_args()

wf = json.loads((Path(__file__).parent / "workflow_api.json").read_text())
wf["85"]["inputs"]["string"] = args.prompt  # replaces [prompt] in the style string
wf["25"]["inputs"]["noise_seed"] = args.seed

req = urllib.request.Request(
    f"https://api.runpod.ai/v2/{os.environ['ENDPOINT_ID']}/runsync",
    data=json.dumps({"input": {"workflow": wf}}).encode(),
    headers={"Authorization": f"Bearer {os.environ['RUNPOD_API_KEY']}", "Content-Type": "application/json"},
)
res = json.load(urllib.request.urlopen(req, timeout=600))
if res.get("status") != "COMPLETED":
    raise SystemExit(json.dumps(res, indent=2))

out = Path(args.out)
out.mkdir(exist_ok=True)
for img in res["output"]["images"]:
    data = img["data"].split(",", 1)[-1]
    (out / img["filename"]).write_bytes(base64.b64decode(data))
    print(out / img["filename"])
