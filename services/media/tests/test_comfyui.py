"""The ComfyUI stylizer: workflows, the ComfyUI API calls, auth, privacy and a
whole job (portrait + 14 frames) against a fake ComfyUI server."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient
from test_avatar import BUILT
from test_frames import (
    APPROVED,
    NOW,
    PROMPTS,
    BlockLocator,
    Checker,
    MintCutter,
    frame_of,
    picture,
)

from media.app import Services, Settings, create_app
from media.auth import FakeAuthenticator
from media.comfyui import (
    WORKFLOWS,
    ApiKeyHeader,
    ComfyUISettings,
    ComfyUIStylizer,
    GoogleIdToken,
    Workflow,
    WorkflowError,
    comfyui_stylizers,
)
from media.frames import FrameBuilder, InMemoryFrameStore
from media.jobs import (
    AvatarSource,
    InMemoryAvatarDocs,
    InMemoryCosts,
    InMemoryJobs,
    InMemoryNotifier,
    InMemoryPortraits,
    JobRunner,
    JobStatus,
    new_job,
)
from media.prompts import FRAMES, OptionBook
from media.safety import FakeInspector
from media.stylizer import EndpointNotApproved, NotConfiguredStylizer, StylizerError

REPO = Path(__file__).resolve().parents[3]
OPTIONS = OptionBook.load(REPO / "content" / "avatar" / "options.json")
URL = "https://stylizer.test.livewell"
SELFIE = b"\xff\xd8\xff\xe0selfie-bytes"
PORTRAIT_WF = Workflow.load(WORKFLOWS / "avatar_portrait.json")
FRAMES_WF = Workflow.load(WORKFLOWS / "avatar_frames.json")


@dataclass
class FakeComfy:
    """A ComfyUI server in memory, with the API the client uses."""

    #: /history answers "not yet" this many times per job.
    pending_polls: int = 2
    fail_prompt: int = 0
    job_error: bool = False
    no_images: bool = False
    never_done: bool = False
    images: Any = None
    uploads: dict[str, bytes] = field(default_factory=dict)
    graphs: dict[str, dict[str, Any]] = field(default_factory=dict)
    polls: dict[str, int] = field(default_factory=dict)
    forgotten: list[dict[str, str]] = field(default_factory=list)
    history_deleted: list[str] = field(default_factory=list)
    queue_deleted: list[str] = field(default_factory=list)
    headers: list[httpx.Headers] = field(default_factory=list)
    calls: list[str] = field(default_factory=list)

    def handle(self, request: httpx.Request) -> httpx.Response:
        self.headers.append(request.headers)
        path = request.url.path
        self.calls.append(f"{request.method} {path}")
        if path == "/upload/image":
            body = request.content
            name = body.split(b'filename="')[1].split(b'"')[0].decode()
            self.uploads[name] = body
            return httpx.Response(200, json={"name": name, "subfolder": "", "type": "input"})
        if path == "/prompt":
            if self.fail_prompt > 0:
                self.fail_prompt -= 1
                return httpx.Response(400, json={"error": "bad", "node_errors": {}})
            prompt_id = f"p{len(self.graphs) + 1}"
            self.graphs[prompt_id] = json.loads(request.content)["prompt"]
            return httpx.Response(200, json={"prompt_id": prompt_id, "number": 1})
        if path.startswith("/history/"):
            prompt_id = path.rsplit("/", 1)[1]
            n = self.polls[prompt_id] = self.polls.get(prompt_id, 0) + 1
            if self.never_done or n <= self.pending_polls:
                return httpx.Response(200, json={})
            if self.job_error:
                status = {"status_str": "error", "completed": False}
                return httpx.Response(200, json={prompt_id: {"status": status, "outputs": {}}})
            images = (
                [] if self.no_images else [{"filename": f"lw_{prompt_id}.png", "type": "output"}]
            )
            entry = {
                "status": {"status_str": "success", "completed": True},
                "outputs": {"14": {"images": images}},
            }
            return httpx.Response(200, json={prompt_id: entry})
        if path == "/view":
            prompt_id = request.url.params["filename"].removeprefix("lw_").removesuffix(".png")
            return httpx.Response(200, content=self.image_for(self.graphs[prompt_id]))
        if path == "/livewell/forget":
            self.forgotten.extend(json.loads(request.content)["files"])
            return httpx.Response(200, json={"removed": 1})
        if path == "/history":
            self.history_deleted.extend(json.loads(request.content)["delete"])
            return httpx.Response(200, json={})
        if path == "/queue":
            self.queue_deleted.extend(json.loads(request.content)["delete"])
            return httpx.Response(200, json={})
        return httpx.Response(404)

    def image_for(self, graph: dict[str, Any]) -> bytes:
        if self.images is not None:
            return bytes(self.images(graph))
        return b"\x89PNG-made"

    @property
    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self.handle)


def stylizer(
    comfy: FakeComfy,
    workflow: Workflow = PORTRAIT_WF,
    approved: frozenset[str] = APPROVED,
    url: str = URL,
    **kw: Any,
) -> ComfyUIStylizer:
    clock = iter(float(i) for i in range(10_000))
    return ComfyUIStylizer(
        endpoint=url,
        workflow=workflow,
        auth=ApiKeyHeader("test-key"),
        approved_hosts=approved,
        transport=comfy.transport,
        sleep=lambda _: None,
        clock=lambda: next(clock),
        **kw,
    )


def positive(graph: dict[str, Any]) -> str:
    return str(graph["9"]["inputs"]["prompt"])


# ---------- the workflow files ----------


def test_the_workflows_load_and_have_the_right_graphs() -> None:
    assert set(PORTRAIT_WF.graphs) == {"image", "text"}
    assert set(FRAMES_WF.graphs) == {"image"}
    for wf in (PORTRAIT_WF, FRAMES_WF):
        assert wf.output_node == "14"
        for graph in wf.graphs.values():
            assert graph["14"]["class_type"] == "SaveImage"


def test_one_diffusion_model_for_every_path_so_it_stays_on_one_l4() -> None:
    loaders = {
        node["inputs"]["unet_name"]
        for wf in (PORTRAIT_WF, FRAMES_WF)
        for graph in wf.graphs.values()
        for node in graph.values()
        if node["class_type"] == "UnetLoaderGGUF"
    }
    assert loaders == {"qwen-image-edit-2511-Q5_K_M.gguf"}


def test_every_model_named_in_a_graph_is_listed_and_listed_in_the_licences() -> None:
    licences = (REPO / "docs" / "design" / "asset-licences.md").read_text(encoding="utf-8")
    for wf in (PORTRAIT_WF, FRAMES_WF):
        named = {
            v
            for graph in wf.graphs.values()
            for node in graph.values()
            for k, v in node["inputs"].items()
            if k in {"unet_name", "clip_name", "vae_name", "lora_name"}
        }
        assert named == set(wf.models)
        for file in wf.models:
            assert file in licences, file


def test_every_model_has_a_commercial_licence() -> None:
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "download_models", REPO / "services" / "media" / "comfyui" / "download_models.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    found = module.models()
    assert len(found) == 4
    assert module.check_licences(found) == []
    # A non-commercial model stops the download.
    found["x.safetensors"] = {"file": "x.safetensors", "licence": "CC-BY-NC-4.0"}
    assert module.check_licences(found) == [
        "x.safetensors: CC-BY-NC-4.0 is not cleared for commercial use"
    ]


def test_a_broken_workflow_is_refused_when_the_service_starts(tmp_path: Path) -> None:
    raw = json.loads((WORKFLOWS / "avatar_frames.json").read_text(encoding="utf-8"))
    raw["graphs"]["image"]["7"]["inputs"]["image"] = "fixed.png"
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps(raw), encoding="utf-8")
    with pytest.raises(WorkflowError, match="INPUT_IMAGE"):
        Workflow.load(bad)
    bad.write_text("{}", encoding="utf-8")
    with pytest.raises(WorkflowError):
        Workflow.load(bad)


def test_fill_replaces_the_placeholders_without_changing_the_graph() -> None:
    tricky = 'smile", "class_type": "Evil'
    graph = PORTRAIT_WF.fill(tricky, "no text", "lw-a.jpg", 42)
    assert positive(graph) == tricky
    assert graph["10"]["inputs"]["prompt"] == "no text"
    assert graph["7"]["inputs"]["image"] == "lw-a.jpg"
    assert graph["12"]["inputs"]["seed"] == 42
    assert set(graph) == set(PORTRAIT_WF.graphs["image"])
    assert "{{" not in json.dumps(graph)
    # The template itself is untouched.
    assert PORTRAIT_WF.graphs["image"]["12"]["inputs"]["seed"] == "{{SEED}}"


def test_build_my_own_uses_the_text_graph_and_frames_need_an_image() -> None:
    graph = PORTRAIT_WF.fill("a portrait", "avoid", None, 1)
    assert graph["11"]["class_type"] == "EmptySD3LatentImage"
    assert all(n["class_type"] != "LoadImage" for n in graph.values())
    with pytest.raises(StylizerError):
        FRAMES_WF.fill("a frame", "avoid", None, 1)


# ---------- the ComfyUI API ----------


def test_one_image_upload_queue_wait_download_then_forget() -> None:
    comfy = FakeComfy()
    s = stylizer(comfy, usd_per_second=0.001)
    made = s.generate("a 3D portrait", "no children", SELFIE)
    assert made.image == b"\x89PNG-made"
    assert made.model == "comfyui:avatar_portrait@1"
    assert made.cost_usd > 0
    assert comfy.calls == [
        "POST /upload/image",
        "POST /prompt",
        "GET /history/p1",
        "GET /history/p1",
        "GET /history/p1",
        "GET /view",
        "POST /livewell/forget",
        "POST /history",
    ]
    (name,) = comfy.uploads
    # A random name: nothing about the person.
    assert name.startswith("lw-") and name.endswith(".jpg")
    assert SELFIE in comfy.uploads[name]
    graph = comfy.graphs["p1"]
    assert graph["7"]["inputs"]["image"] == name
    assert positive(graph) == "a 3D portrait"
    assert isinstance(graph["12"]["inputs"]["seed"], int)
    # The input photo and the result are deleted from ComfyUI, and the job.
    assert {f["name"] for f in comfy.forgotten} == {name, "lw_p1.png"}
    assert comfy.history_deleted == ["p1"]
    assert all(h["X-Api-Key"] == "test-key" for h in comfy.headers)


def test_build_my_own_uploads_nothing() -> None:
    comfy = FakeComfy()
    stylizer(comfy).generate("a portrait", "avoid", None)
    assert comfy.uploads == {}
    assert comfy.graphs["p1"]["11"]["class_type"] == "EmptySD3LatentImage"


@pytest.mark.parametrize(
    ("setup", "why"),
    [
        ({"fail_prompt": 1}, "refused the workflow"),
        ({"job_error": True}, "job failed"),
        ({"no_images": True}, "no image"),
        ({"never_done": True}, "too long"),
    ],
)
def test_comfyui_failures_are_stylizer_errors_and_still_forget(
    setup: dict[str, Any], why: str
) -> None:
    comfy = FakeComfy(**setup)
    with pytest.raises(StylizerError, match=why):
        stylizer(comfy, timeout_s=5).generate("p", "a", SELFIE)
    assert [f["type"] for f in comfy.forgotten][:1] == ["input"]
    if setup.get("never_done"):
        assert comfy.queue_deleted == ["p1"]


def test_an_unreachable_server_is_a_stylizer_error() -> None:
    def down(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("down", request=request)

    s = stylizer(FakeComfy())
    s.transport = httpx.MockTransport(down)
    with pytest.raises(StylizerError, match="reached"):
        s.generate("p", "a", SELFIE)


@pytest.mark.parametrize(
    ("url", "approved"),
    [
        ("http://stylizer.test.livewell", APPROVED),
        ("https://other.example.com", APPROVED),
        ("https://my-comfy.hf.space", frozenset({"my-comfy.hf.space"})),
        ("https://abc.gradio.live", frozenset({"abc.gradio.live"})),
        ("https://x.ngrok-free.app", frozenset({"x.ngrok-free.app"})),
    ],
)
def test_photos_never_go_to_an_unapproved_or_public_server(
    url: str, approved: frozenset[str]
) -> None:
    comfy = FakeComfy()
    with pytest.raises(EndpointNotApproved):
        stylizer(comfy, url=url, approved=approved).generate("p", "a", SELFIE)
    assert comfy.calls == []


def test_only_images_are_uploaded() -> None:
    with pytest.raises(StylizerError):
        stylizer(FakeComfy()).generate("p", "a", b"not an image")


def test_nothing_personal_in_the_logs(caplog: pytest.LogCaptureFixture) -> None:
    comfy = FakeComfy(fail_prompt=1)
    caplog.set_level(logging.DEBUG)
    s = stylizer(comfy)
    with pytest.raises(StylizerError):
        s.generate("secret prompt words", "a", SELFIE)
    s.generate("secret prompt words", "a", SELFIE)
    text = caplog.text
    assert "secret prompt" not in text
    assert "lw-" not in text


# ---------- who may call ComfyUI ----------


def test_google_id_token_is_the_main_option_and_is_reused() -> None:
    fetched: list[str] = []
    now = [0.0]

    def fetch(audience: str) -> str:
        fetched.append(audience)
        return f"token{len(fetched)}"

    auth = GoogleIdToken(audience=URL, fetch=fetch, now=lambda: now[0])
    assert auth.headers() == {"Authorization": "Bearer token1"}
    now[0] = 60 * 49
    assert auth.headers() == {"Authorization": "Bearer token1"}
    now[0] = 60 * 51
    assert auth.headers() == {"Authorization": "Bearer token2"}
    assert fetched == [URL, URL]


def test_the_id_token_comes_from_the_metadata_server(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[httpx.Request] = []

    def fake_get(url: str, **kw: Any) -> httpx.Response:
        request = httpx.Request("GET", url, params=kw["params"], headers=kw["headers"])
        seen.append(request)
        return httpx.Response(200, text="id-token\n", request=request)

    monkeypatch.setattr(httpx, "get", fake_get)
    assert GoogleIdToken(audience=URL).headers() == {"Authorization": "Bearer id-token"}
    assert seen[0].url.host == "metadata.google.internal"
    assert seen[0].url.params["audience"] == URL
    assert seen[0].headers["Metadata-Flavor"] == "Google"


def test_settings_from_the_environment() -> None:
    assert ComfyUISettings.from_env({}) is None
    s = ComfyUISettings.from_env({"MEDIA_COMFYUI_URL": URL})
    assert s is not None and isinstance(s.authenticator(), GoogleIdToken)
    s = ComfyUISettings.from_env(
        {
            "MEDIA_COMFYUI_URL": URL,
            "MEDIA_COMFYUI_AUTH": "api_key",
            "MEDIA_COMFYUI_API_KEY": "sekrit-key",
        }
    )
    assert s is not None
    assert s.authenticator().headers() == {"X-Api-Key": "sekrit-key"}
    assert "sekrit" not in repr(s)
    assert "sekrit" not in repr(s.authenticator())
    with pytest.raises(WorkflowError):
        ComfyUISettings(url=URL, auth="api_key").authenticator()
    with pytest.raises(WorkflowError):
        ComfyUISettings(url=URL, auth="password").authenticator()


def test_the_service_uses_comfyui_only_when_configured() -> None:
    off = Services.from_env({})
    assert isinstance(off.stylizer, NotConfiguredStylizer)
    assert off.settings.approved_hosts == frozenset()
    on = Services.from_env(
        {
            "MEDIA_COMFYUI_URL": URL,
            "MEDIA_APPROVED_HOSTS": " Stylizer.test.livewell ,",
        }
    )
    assert isinstance(on.stylizer, ComfyUIStylizer)
    assert isinstance(on.frame_stylizer, ComfyUIStylizer)
    assert on.stylizer.workflow.name == "avatar_portrait"
    assert on.frame_stylizer.workflow.name == "avatar_frames"
    assert on.settings.approved_hosts == APPROVED


# ---------- a whole job against the fake server ----------


def drawn(graph: dict[str, Any]) -> bytes:
    """The fake server 'draws' a face block that moves with each image."""
    n = int(graph["12"]["inputs"]["seed"]) % 40
    return picture((100 + n, 150 + n, 200 + n, 260 + n))


def full_runner(
    comfy: FakeComfy, notifier: InMemoryNotifier
) -> tuple[JobRunner, InMemoryJobs, InMemoryFrameStore, InMemoryAvatarDocs]:
    portrait, frames = comfyui_stylizers(
        ComfyUISettings(url=URL, auth="api_key", api_key="k"),
        APPROVED,
        transport=comfy.transport,
    )
    for s in (portrait, frames):
        s.sleep = lambda _: None
    jobs, store, docs, costs = (
        InMemoryJobs(),
        InMemoryFrameStore(),
        InMemoryAvatarDocs(),
        InMemoryCosts(),
    )
    runner = JobRunner(
        prompts=PROMPTS,
        options=OPTIONS,
        stylizer=portrait,
        inspector=FakeInspector(),
        jobs=jobs,
        portraits=InMemoryPortraits(),
        costs=costs,
        approved_hosts=APPROVED,
        frames=FrameBuilder(
            prompts=PROMPTS,
            stylizer=frames,
            locator=BlockLocator(),
            remover=MintCutter(),
            checker=Checker(),
            store=store,
            costs=costs,
            approved_hosts=APPROVED,
            clock=lambda: NOW,
        ),
        docs=docs,
        notifier=notifier,
        clock=lambda: NOW,
    )
    return runner, jobs, store, docs


def test_from_my_photo_the_portrait_and_14_frames_through_comfyui() -> None:
    comfy = FakeComfy(pending_polls=0, images=drawn)
    notifier = InMemoryNotifier()
    runner, _, store, docs = full_runner(comfy, notifier)
    job = runner.run(new_job("u1", AvatarSource.SELFIE, {}, NOW), SELFIE)
    assert job.status is JobStatus.SUCCEEDED, job
    assert job.frames_version == 1
    # 1 portrait + 14 frames, each its own ComfyUI job.
    assert len(comfy.graphs) == 1 + len(FRAMES)
    first = comfy.graphs["p1"]
    assert first["7"]["inputs"]["image"] in comfy.uploads
    frames_made = [frame_of(positive(g)) for g in list(comfy.graphs.values())[1:]]
    assert sorted(frames_made) == sorted(FRAMES)
    # Only the first upload is the selfie; the rest are our own images.
    uploads = list(comfy.uploads.values())
    assert SELFIE in uploads[0]
    assert all(SELFIE not in u for u in uploads[1:])
    # Every image in and out was deleted from ComfyUI.
    assert {f["name"] for f in comfy.forgotten if f["type"] == "input"} == set(comfy.uploads)
    assert len(comfy.history_deleted) == len(comfy.graphs)
    assert ("u1", 1, "avatar_frames.json") in store.files
    assert docs.docs["u1"]["source"] == "selfie"
    assert notifier.sent == [("u1", job.id, True)]


def test_build_my_own_through_comfyui() -> None:
    comfy = FakeComfy(pending_polls=0, images=drawn)
    notifier = InMemoryNotifier()
    runner, _, _, docs = full_runner(comfy, notifier)
    job = runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert job.status is JobStatus.SUCCEEDED
    assert comfy.graphs["p1"]["11"]["class_type"] == "EmptySD3LatentImage"
    assert docs.docs["u1"]["source"] == "built"
    assert notifier.sent == [("u1", job.id, True)]


def test_a_failed_job_also_notifies_and_a_failed_push_never_fails_the_job() -> None:
    comfy = FakeComfy(job_error=True)
    notifier = InMemoryNotifier()
    runner, _, _, _ = full_runner(comfy, notifier)
    job = runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert job.status is JobStatus.FAILED
    assert job.attempts == 2
    assert notifier.sent == [("u1", job.id, False)]

    class Broken:
        def job_done(self, uid: str, job_id: str, made: bool) -> None:
            raise RuntimeError("fcm down")

    runner.notifier = Broken()
    assert runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW)).status is JobStatus.FAILED


def test_the_http_service_with_comfyui_end_to_end() -> None:
    comfy = FakeComfy(pending_polls=0, images=drawn)
    portrait, frames = comfyui_stylizers(
        ComfyUISettings(url=URL, auth="api_key", api_key="k"), APPROVED, transport=comfy.transport
    )
    notifier = InMemoryNotifier()
    services = Services(
        settings=Settings(approved_hosts=APPROVED),
        auth=FakeAuthenticator(),
        stylizer=portrait,
        frame_stylizer=frames,
        inspector=FakeInspector(),
        locator=BlockLocator(),
        remover=MintCutter(),
        checker=Checker(),
        jobs=InMemoryJobs(),
        notifier=notifier,
        clock=lambda: NOW,
    )
    client = TestClient(create_app(services))
    headers = {"Authorization": "Bearer token-u1", "X-Firebase-AppCheck": "app-check-ok"}
    r = client.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers)
    assert r.status_code == 202
    status = client.get(f"/v1/avatar/jobs/{r.json()['job_id']}", headers=headers).json()
    assert status["status"] == "succeeded"
    assert status["frames_version"] == 1
    assert len(comfy.graphs) == 1 + len(FRAMES)
    assert [made for _, _, made in notifier.sent] == [True]
