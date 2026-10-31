"""Downloads every model the workflows need from Hugging Face into one folder
laid out for ComfyUI (unet/, text_encoders/, vae/, loras/), ready to copy to
the Cloud Storage bucket (docs/media/comfyui-setup.md, step 4).

Refuses any model whose licence isn't on the commercial-use list: a
non-commercial model is a blocker (docs/design/asset-licences.md).

    pip install "huggingface_hub>=0.25"
    HF_TOKEN=... python services/media/comfyui/download_models.py /data/models

`--dev` downloads the free laptop models instead (workflows/sd15-dev, D-64).
They are checked against DEV_ONLY, never against the prod list, and are never
deployed.

    python services/media/comfyui/download_models.py --dev D:/ComfyUI-models

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

#: The developer's laptop only (D-64): SD 1.5 and its add-ons. Never added to
#: COMMERCIAL_OK, and the prod workflows can't name them (test_local_dev).
DEV_WORKFLOWS = WORKFLOWS / "sd15-dev"
DEV_ONLY = COMMERCIAL_OK | {"CreativeML-OpenRAIL-M", "OpenRAIL++"}


def models(folder: Path = WORKFLOWS) -> dict[str, dict[str, str]]:
    """Every model named by a workflow in [folder], by file name."""
    found: dict[str, dict[str, str]] = {}
    for path in sorted(folder.glob("*.json")):
        for model in json.loads(path.read_text(encoding="utf-8"))["models"]:
            found[model["file"]] = model
    return found


def check_licences(
    found: dict[str, dict[str, str]], allowed: set[str] = COMMERCIAL_OK
) -> list[str]:
    return [
        f"{m['file']}: {m['licence']} is not cleared for commercial use"
        for m in found.values()
        if m["licence"] not in allowed
    ]


def main(target: Path, dev: bool = False) -> int:
    found = models(DEV_WORKFLOWS) if dev else models()
    blockers = check_licences(found, DEV_ONLY if dev else COMMERCIAL_OK)
    if blockers:
        print("\n".join(blockers), file=sys.stderr)
        return 1
    from huggingface_hub import hf_hub_download

    for model in found.values():
        folder = target / model["folder"]
        folder.mkdir(parents=True, exist_ok=True)
        print(f"{model['repo']}/{model['repo_path']} -> {model['folder']}/{model['file']}")
        downloaded = hf_hub_download(model["repo"], model["repo_path"], local_dir=target / ".hf")
        if model.get("convert", "").startswith("fp16"):
            to_fp16(Path(downloaded), folder / model["file"])
        else:
            shutil.move(downloaded, folder / model["file"])
    shutil.rmtree(target / ".hf", ignore_errors=True)
    return 0


def to_fp16(src: Path, dst: Path) -> None:
    """Half the size (a 4 GB laptop GPU and 8 GB of RAM, D-64)."""
    from safetensors import safe_open
    from safetensors.torch import save_file

    out = {}
    with safe_open(str(src), "pt") as f:
        for key in f.keys():  # noqa: SIM118 (a safetensors file, not a dict)
            t = f.get_tensor(key)
            out[key] = (t.half() if t.is_floating_point() else t).clone()
    save_file(out, str(dst))


if __name__ == "__main__":
    args = sys.argv[1:]
    dev = args[:1] == ["--dev"]
    if dev:
        args = args[1:]
    if len(args) != 1:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(main(Path(args[0]), dev=dev))
