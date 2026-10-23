"""Downloads every model the workflows need from Hugging Face into one folder
laid out for ComfyUI (unet/, text_encoders/, vae/, loras/), ready to copy to
the Cloud Storage bucket (docs/media/comfyui-setup.md, step 4).

Refuses any model whose licence isn't on the commercial-use list: a
non-commercial model is a blocker (docs/design/asset-licences.md).

    pip install "huggingface_hub>=0.25"
    HF_TOKEN=... python services/media/comfyui/download_models.py /data/models

The Hugging Face token is read from HF_TOKEN (a Secret Manager secret on the
machine that runs this); it is never written anywhere.
"""

import json
import shutil
import sys
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[1] / "workflows"

#: Licences we may use commercially. Anything else stops the download.
COMMERCIAL_OK = {"Apache-2.0", "MIT"}


def models() -> dict[str, dict[str, str]]:
    """Every model named by a workflow, by file name."""
    found: dict[str, dict[str, str]] = {}
    for path in sorted(WORKFLOWS.glob("*.json")):
        for model in json.loads(path.read_text(encoding="utf-8"))["models"]:
            found[model["file"]] = model
    return found


def check_licences(found: dict[str, dict[str, str]]) -> list[str]:
    return [
        f"{m['file']}: {m['licence']} is not cleared for commercial use"
        for m in found.values()
        if m["licence"] not in COMMERCIAL_OK
    ]


def main(target: Path) -> int:
    found = models()
    blockers = check_licences(found)
    if blockers:
        print("\n".join(blockers), file=sys.stderr)
        return 1
    from huggingface_hub import hf_hub_download

    for model in found.values():
        folder = target / model["folder"]
        folder.mkdir(parents=True, exist_ok=True)
        print(f"{model['repo']}/{model['repo_path']} -> {model['folder']}/{model['file']}")
        downloaded = hf_hub_download(model["repo"], model["repo_path"], local_dir=target / ".hf")
        shutil.move(downloaded, folder / model["file"])
    shutil.rmtree(target / ".hf", ignore_errors=True)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(main(Path(sys.argv[1])))
