"""D-64, free route: a ComfyUI on this computer (SD 1.5, dev only), one AI
portrait with the blink and mouth frames drawn, and checks that run locally."""

from __future__ import annotations

import io
from pathlib import Path

import pytest
from PIL import Image
from test_frames import builder, picture

from media.app import Services
from media.comfyui import (
    ComfyUISettings,
    NoAuth,
    Workflow,
    WorkflowError,
    comfyui_stylizers,
)
from media.frames import FaceBox
from media.local_checks import CONCERNS, LocalInspector, SkinToneKeeper
from media.prompts import FRAMES
from media.stylizer import EndpointNotApproved, check_endpoint

SD15 = Path(__file__).resolve().parents[1] / "workflows" / "sd15-dev"
LOCAL = "http://127.0.0.1:6800"
LOCAL_ONLY = frozenset({"127.0.0.1"})


# --- Plain HTTP only to this computer -------------------------------------


def test_http_to_an_approved_loopback_host_is_allowed() -> None:
    check_endpoint(LOCAL, LOCAL_ONLY)
    check_endpoint("http://localhost:6800", frozenset({"localhost"}))


@pytest.mark.parametrize(
    ("url", "approved"),
    [
        (LOCAL, frozenset({"stylizer.test.livewell"})),  # loopback not approved
        ("http://stylizer.test.livewell", frozenset({"stylizer.test.livewell"})),
        ("http://192.168.1.5:6800", frozenset({"192.168.1.5"})),  # the LAN is not loopback
        ("ftp://127.0.0.1", LOCAL_ONLY),
    ],
)
def test_other_plain_http_is_still_refused(url: str, approved: frozenset[str]) -> None:
    with pytest.raises(EndpointNotApproved):
        check_endpoint(url, approved)


def test_no_login_only_for_a_comfyui_on_this_computer() -> None:
    assert isinstance(ComfyUISettings(url=LOCAL, auth="none").authenticator(), NoAuth)
    with pytest.raises(WorkflowError):
        ComfyUISettings(url="https://comfy.example.run.app", auth="none").authenticator()


def test_a_loopback_host_needs_the_dev_switch() -> None:
    env = {"MEDIA_APPROVED_HOSTS": "127.0.0.1"}
    with pytest.raises(ValueError, match="MEDIA_ALLOW_LOOPBACK"):
        Services.from_env(env)
    Services.from_env({**env, "MEDIA_ALLOW_LOOPBACK": "1"})


# --- The SD 1.5 dev workflows ----------------------------------------------


def test_the_dev_workflows_load_and_are_wired_from_env() -> None:
    names = {Workflow.load(p).name for p in SD15.glob("*.json")}
    assert names == {
        "avatar_portrait_sd15_dev",
        "avatar_frames_sd15_dev",
    }
    s = Services.from_env(
        {
            "MEDIA_COMFYUI_URL": LOCAL,
            "MEDIA_COMFYUI_AUTH": "none",
            "MEDIA_ALLOW_LOOPBACK": "1",
            "MEDIA_APPROVED_HOSTS": "127.0.0.1",
            "MEDIA_WORKFLOWS_PATH": str(SD15),
        }
    )
    assert s.stylizer.endpoint == LOCAL
    assert s.drawer is None  # only with MEDIA_DRAWN_FRAMES


def test_the_prod_workflows_are_unchanged() -> None:
    settings = ComfyUISettings(url="https://comfy.example.run.app", auth="api_key", api_key="k")
    portrait, frames = comfyui_stylizers(settings, frozenset({"comfy.example.run.app"}))
    assert portrait.workflow.name == "avatar_portrait"
    assert frames.workflow.name == "avatar_frames"


def test_dev_models_are_never_on_the_prod_licence_list() -> None:
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "download_models", SD15.parents[1] / "comfyui" / "download_models.py"
    )
    assert spec is not None and spec.loader is not None
    dm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dm)
    prod = dm.models()
    assert not dm.check_licences(prod)
    assert not any("v1-5" in f for f in prod)
    dev = dm.models(dm.DEV_WORKFLOWS)
    assert dm.check_licences(dev)  # blocked by the prod list
    assert not dm.check_licences(dev, dm.DEV_ONLY)
    assert "CreativeML-OpenRAIL-M" not in dm.COMMERCIAL_OK


# --- One AI portrait, the blink and mouth frames drawn --------------------


DRAWN = frozenset({"blink", "mouth_closed", "mouth_A", "mouth_E", "mouth_I", "mouth_O", "mouth_U"})


class FakeDrawer:
    frames = DRAWN

    def __init__(self, fail: set[str] | None = None) -> None:
        self.fail = fail or set()
        self.drawn: list[str] = []

    def draw(self, neutral: Image.Image, frame: str) -> Image.Image | None:
        self.drawn.append(frame)
        return None if frame in self.fail else neutral.copy()


def test_with_a_drawer_no_frame_goes_to_the_image_model() -> None:
    b, _, _, stylizer = builder()
    drawer = FakeDrawer()
    b.drawer = drawer
    fs = b.build("u1", picture((300, 200, 240, 300)), "job1")
    assert stylizer.calls == []
    assert set(drawer.drawn) == DRAWN
    assert fs.fell_back == ()
    # Expressions show the neutral face (they move in code).
    assert fs.manifest["frames"]["happy"] == fs.manifest["frames"]["neutral"]  # type: ignore[index]


def test_a_failed_drawing_falls_back_to_neutral() -> None:
    b, _, _, _ = builder()
    b.drawer = FakeDrawer(fail={"mouth_O"})
    fs = b.build("u1", picture((300, 200, 240, 300)), "job1")
    assert fs.fell_back == ("mouth_O",)


def test_the_drawn_frames_are_blink_and_every_mouth_shape() -> None:
    from media.drawn_frames import DRAWN as REAL  # needs the local extra

    assert {f for f in FRAMES if f == "blink" or f.startswith("mouth_")} == set(REAL)


def test_without_a_drawer_every_frame_is_made_by_the_model() -> None:
    b, _, _, main = builder()
    b.build("u1", b"portrait", "job1")
    assert {f for f, _ in main.calls} == set(FRAMES)


# --- The skin tone is kept ---------------------------------------------------


class WholeImageFace:
    def detect(self, image: Image.Image) -> list[tuple[FaceBox, object]]:
        return [(FaceBox(0, 0, image.width, image.height), None)]


class LighterStylizer:
    endpoint = LOCAL

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> object:
        from media.stylizer import Generated

        return Generated(solid((230, 200, 180)), 0.0, "fake")


def solid(rgb: tuple[int, int, int]) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (64, 64), rgb).save(out, "PNG")
    return out.getvalue()


def test_the_portrait_gets_the_selfies_skin_tone() -> None:
    keeper = SkinToneKeeper(LighterStylizer(), WholeImageFace())  # type: ignore[arg-type]
    selfie = solid((120, 80, 60))
    made = keeper.generate("p", "a", selfie)
    r, g, b = Image.open(io.BytesIO(made.image)).convert("RGB").getpixel((32, 32))  # type: ignore[misc]
    assert abs(r - 120) <= 6 and abs(g - 80) <= 6 and abs(b - 60) <= 6
    assert keeper.endpoint == LOCAL


def test_without_a_selfie_the_portrait_is_unchanged() -> None:
    keeper = SkinToneKeeper(LighterStylizer(), WholeImageFace())  # type: ignore[arg-type]
    made = keeper.generate("p", "a", None)
    assert made.image == solid((230, 200, 180))


# --- Local checks fail safe --------------------------------------------------


class Faces:
    def __init__(self, n: int) -> None:
        self.n = n

    def detect(self, image: Image.Image) -> list[object]:
        return [object()] * self.n


class Likeness:
    def __init__(self, score: float) -> None:
        self.score = score

    def similarity(self, portrait: Image.Image, selfie: Image.Image) -> float:
        return self.score


class Concerns:
    def __init__(self, raised: set[str] | Exception) -> None:
        self.r = raised

    def raised(self, image: Image.Image) -> set[str]:
        if isinstance(self.r, Exception):
            raise self.r
        return self.r


def png_bytes() -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (16, 16), "white").save(out, "PNG")
    return out.getvalue()


def inspector(faces: int, score: float, raised: set[str] | Exception) -> LocalInspector:
    return LocalInspector(Faces(faces), Likeness(score), Concerns(raised))  # type: ignore[arg-type]


def test_local_inspector_reports_the_facts() -> None:
    facts = inspector(1, 0.7, {"text_or_logo"}).inspect(png_bytes(), png_bytes())
    assert facts.face_count == 1 and facts.similarity == 0.7
    assert facts.text_or_logo and not facts.nudity and not facts.violence
    assert not facts.looks_under_18


def test_a_child_looking_signal_rejects() -> None:
    assert inspector(1, 0.9, {"child"}).inspect(png_bytes(), None).looks_under_18


def test_no_selfie_no_likeness() -> None:
    assert inspector(1, 0.9, set()).inspect(png_bytes(), None).similarity is None


def test_local_inspector_fails_safe() -> None:
    facts = inspector(1, 0.9, RuntimeError("model missing")).inspect(png_bytes(), png_bytes())
    assert facts.face_count == 0 and facts.looks_under_18


def test_every_concern_has_descriptions_and_a_low_limit() -> None:
    for texts, limit in CONCERNS.values():
        assert texts and 0 < limit < 0.5


def test_every_file_a_frame_set_writes_fits_the_local_store(tmp_path: Path) -> None:
    from media.local_files import LocalFrameStore

    b, store, _, _ = builder()
    b.build("u1", b"portrait", "job1")
    names = {name for (_, _, name) in store.files}
    assert "mouth_A@3x.webp" in names
    local = LocalFrameStore(tmp_path)
    for name in names:
        local.put("u1", 1, name, b"x")  # raises on a name it refuses
