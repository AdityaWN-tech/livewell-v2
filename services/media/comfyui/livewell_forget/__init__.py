"""A ComfyUI add-on for Live Well: POST /livewell/forget deletes the images
a job used and made (the selfie, the portrait, the frame), so no photo stays
on the ComfyUI server after the Media Service has downloaded the result.

Body: {"files": [{"name": "lw-....png", "subfolder": "", "type": "input"}]}
Only files inside ComfyUI's input, output and temp folders can be deleted,
and only ones named by the Media Service (lw-*). It adds no nodes.
"""

import os

import folder_paths  # type: ignore[import-not-found]
from aiohttp import web
from server import PromptServer  # type: ignore[import-not-found]

NODE_CLASS_MAPPINGS: dict[str, object] = {}

_FOLDERS = {
    "input": folder_paths.get_input_directory,
    "output": folder_paths.get_output_directory,
    "temp": folder_paths.get_temp_directory,
}


def _path(item: dict[str, str]) -> str | None:
    folder = _FOLDERS.get(item.get("type", ""))
    name = item.get("name", "")
    if folder is None or not name.startswith("lw"):
        return None
    root = os.path.realpath(folder())
    path = os.path.realpath(os.path.join(root, item.get("subfolder", ""), name))
    # Never outside ComfyUI's own folders.
    if os.path.commonpath([root, path]) != root:
        return None
    return path


@PromptServer.instance.routes.post("/livewell/forget")
async def forget(request: web.Request) -> web.Response:
    body = await request.json()
    removed = 0
    for item in body.get("files", []):
        path = _path(item) if isinstance(item, dict) else None
        if path and os.path.isfile(path):
            os.remove(path)
            removed += 1
    return web.json_response({"removed": removed})
