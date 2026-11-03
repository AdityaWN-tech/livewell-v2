"""The livewell_forget ComfyUI add-on deletes a job's images, and nothing else."""

from __future__ import annotations

import asyncio
import importlib.util
import sys
import types
from pathlib import Path
from typing import Any

import pytest

ADDON = Path(__file__).resolve().parents[1] / "comfyui" / "livewell_forget" / "__init__.py"


class FakeRoutes:
    def __init__(self) -> None:
        self.handlers: dict[str, Any] = {}

    def post(self, path: str) -> Any:
        def register(fn: Any) -> Any:
            self.handlers[path] = fn
            return fn

        return register


class FakeRequest:
    def __init__(self, body: dict[str, Any]) -> None:
        self.body = body

    async def json(self) -> dict[str, Any]:
        return self.body


@pytest.fixture
def addon(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Any, FakeRoutes, Path]:
    pytest.importorskip("aiohttp")
    for folder in ("input", "output", "temp"):
        (tmp_path / folder).mkdir()
    routes = FakeRoutes()
    folder_paths = types.ModuleType("folder_paths")
    folder_paths.get_input_directory = lambda: str(tmp_path / "input")  # type: ignore[attr-defined]
    folder_paths.get_output_directory = lambda: str(tmp_path / "output")  # type: ignore[attr-defined]
    folder_paths.get_temp_directory = lambda: str(tmp_path / "temp")  # type: ignore[attr-defined]
    server = types.ModuleType("server")
    server.PromptServer = types.SimpleNamespace(  # type: ignore[attr-defined]
        instance=types.SimpleNamespace(routes=routes)
    )
    monkeypatch.setitem(sys.modules, "folder_paths", folder_paths)
    monkeypatch.setitem(sys.modules, "server", server)
    spec = importlib.util.spec_from_file_location("livewell_forget", ADDON)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, routes, tmp_path


def forget(routes: FakeRoutes, files: list[dict[str, str]]) -> int:
    response = asyncio.run(routes.handlers["/livewell/forget"](FakeRequest({"files": files})))
    import json

    return int(json.loads(response.text)["removed"])


def test_deletes_the_jobs_input_and_output(addon: tuple[Any, FakeRoutes, Path]) -> None:
    _, routes, root = addon
    selfie = root / "input" / "lw-abc.jpg"
    result = root / "output" / "lw_00001_.png"
    selfie.write_bytes(b"photo")
    result.write_bytes(b"image")
    removed = forget(
        routes,
        [
            {"name": "lw-abc.jpg", "subfolder": "", "type": "input"},
            {"name": "lw_00001_.png", "subfolder": "", "type": "output"},
        ],
    )
    assert removed == 2
    assert not selfie.exists() and not result.exists()


def test_nothing_outside_comfyuis_folders_or_not_ours(addon: tuple[Any, FakeRoutes, Path]) -> None:
    _, routes, root = addon
    outside = root / "lw-secret.txt"
    outside.write_text("keep")
    other = root / "input" / "someone.png"
    other.write_bytes(b"keep")
    removed = forget(
        routes,
        [
            {"name": "../lw-secret.txt", "subfolder": "", "type": "input"},
            {"name": "lw-secret.txt", "subfolder": "..", "type": "input"},
            {"name": "someone.png", "subfolder": "", "type": "input"},
            {"name": "lw-x.png", "subfolder": "", "type": "models"},
            {"name": "lw-missing.png", "subfolder": "", "type": "input"},
        ],
    )
    assert removed == 0
    assert outside.exists() and other.exists()
