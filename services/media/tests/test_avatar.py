"""T-AVT-08c: the avatar generation service."""

from __future__ import annotations

import base64
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from media.app import Services, Settings, create_app
from media.auth import FakeAuthenticator, FakeConsents
from media.jobs import (
    AvatarSource,
    InMemoryCosts,
    InMemoryJobs,
    InMemoryPortraits,
    JobRunner,
    JobStatus,
    Messages,
    new_job,
)
from media.prompts import FRAMES, OptionBook, PromptBook, PromptError
from media.safety import FakeInspector, ImageFacts, Rejection, judge
from media.stylizer import (
    EndpointNotApproved,
    FakeStylizer,
    NotConfiguredStylizer,
    StylizerError,
    check_endpoint,
)

REPO = Path(__file__).resolve().parents[3]
PROMPTS = PromptBook.load(REPO / "docs" / "design" / "avatar-prompts.md")
OPTIONS = OptionBook.load(REPO / "content" / "avatar" / "options.json")
NOW = datetime(2026, 10, 22, 9, 0, tzinfo=UTC)
JPEG = b"\xff\xd8\xff\xe0" + b"selfie-pixels" * 10
APPROVED = frozenset({"stylizer.test.livewell"})

BUILT = {
    "age_range": "40s",
    "face": "oval",
    "skin": "tone_6",
    "eyes": "almond",
    "eyebrows": "natural",
    "nose": "straight",
    "lips": "medium",
    "hairstyle": "curly",
    "hair_colour": "grey",
    "facial_hair": "short_beard",
    "outfit": "knit_sweater",
    "outfit_colour": "navy",
    "glasses": "round",
}

GOOD = ImageFacts(
    1, looks_under_18=False, nudity=False, violence=False, text_or_logo=False, similarity=0.9
)


def facts(**changes: object) -> ImageFacts:
    data = {**GOOD.__dict__, **changes}
    return ImageFacts(**data)  # type: ignore[arg-type]


def runner(
    stylizer: FakeStylizer | None = None,
    inspector: FakeInspector | None = None,
    portraits: InMemoryPortraits | None = None,
) -> tuple[JobRunner, InMemoryJobs, InMemoryCosts]:
    jobs, costs = InMemoryJobs(), InMemoryCosts()
    return (
        JobRunner(
            prompts=PROMPTS,
            options=OPTIONS,
            stylizer=stylizer or FakeStylizer(),
            inspector=inspector or FakeInspector(),
            jobs=jobs,
            portraits=portraits or InMemoryPortraits(),
            costs=costs,
            approved_hosts=APPROVED,
            clock=lambda: NOW,
        ),
        jobs,
        costs,
    )


# ---------- prompts: read from avatar-prompts.md, filled from fixed lists ----


def test_prompts_come_from_the_file() -> None:
    assert PROMPTS.master.startswith("Stylized 3D character portrait of an adult")
    assert "child" in PROMPTS.avoid and "watermark" in PROMPTS.avoid
    assert "[MASTER STYLE]" in PROMPTS.selfie
    assert "[AGE RANGE]" in PROMPTS.build
    assert "[CHANGES]" in PROMPTS.adjust
    assert set(PROMPTS.frame_expressions) == set(FRAMES)


def test_frame_prompts_keep_the_face_and_mouth_frames_keep_the_eyes() -> None:
    p = PROMPTS.frame_prompt("blink")
    assert "Keep exactly the same person" in p and "eyes fully closed" in p
    m = PROMPTS.frame_prompt("mouth_O")
    assert '"oh"' in m and "change only the mouth" in m
    with pytest.raises(PromptError):
        PROMPTS.frame_prompt("wink")


def test_build_my_own_fills_every_placeholder_from_the_lists() -> None:
    text = OPTIONS.fill(PROMPTS.build, BUILT, PROMPTS.master)
    assert "[" not in text and "]" not in text
    assert "in their 40s" in text and "round glasses" in text
    assert "navy" in text and "a short neat beard" in text
    assert text.startswith("Create an original adult character")


def test_no_free_text_ever_reaches_a_prompt() -> None:
    with pytest.raises(PromptError):
        OPTIONS.fill(PROMPTS.build, {**BUILT, "outfit": "a superhero costume"}, PROMPTS.master)
    with pytest.raises(PromptError):
        OPTIONS.fill(PROMPTS.build, {**BUILT, "notes": "make me younger"}, PROMPTS.master)
    # Build needs every face choice.
    with pytest.raises(PromptError):
        OPTIONS.fill(PROMPTS.build, {"age_range": "30s"}, PROMPTS.master)


def test_adults_only_in_the_age_lists() -> None:
    ages = [o.id for o in OPTIONS.categories["age_range"].options]
    assert ages == ["20s", "30s", "40s", "50s", "60s", "70s"]


def test_inclusive_options_are_there() -> None:
    def ids(c: str) -> set[str]:
        return {o.id for o in OPTIONS.categories[c].options}

    assert len(ids("skin")) >= 10
    assert {"hijab", "turban", "kippah"} <= ids("head_covering")
    assert {"hearing_aid", "wheelchair"} <= ids("accessories")
    assert {"grey", "white"} <= ids("hair_colour")


def test_selfie_and_adjust_prompts() -> None:
    selfie = OPTIONS.fill(PROMPTS.selfie, {}, PROMPTS.master)
    assert "identity reference" in selfie and "keep their real age" in selfie
    assert "soft green knit" in selfie  # default outfit
    adjust = OPTIONS.fill(
        PROMPTS.adjust, {"cap": "beanie", "outfit_colour": "plum"}, PROMPTS.master
    )
    assert "Only change: a knit beanie; plum" in adjust
    with pytest.raises(PromptError):
        OPTIONS.fill(PROMPTS.adjust, {}, PROMPTS.master)


# ---------- the endpoint guard: no photos to unapproved or public servers ---


@pytest.mark.parametrize(
    "url",
    [
        "http://stylizer.test.livewell/v1",
        "https://abc123.gradio.live/run",
        "https://someone-model.hf.space/api",
        "https://huggingface.co/spaces/x/y",
        "https://colab.research.google.com/drive/1",
        "https://abcd.ngrok-free.app/",
        "https://elsewhere.example.com/v1",
    ],
)
def test_photos_never_go_to_unapproved_endpoints(url: str) -> None:
    with pytest.raises(EndpointNotApproved):
        check_endpoint(url, APPROVED)


def test_a_demo_host_stays_refused_even_if_approved_by_mistake() -> None:
    with pytest.raises(EndpointNotApproved):
        check_endpoint("https://x.gradio.live/run", APPROVED | {"x.gradio.live"})
    check_endpoint("https://stylizer.test.livewell/v1", APPROVED)


def test_runner_refuses_before_sending_a_selfie_to_an_unapproved_endpoint() -> None:
    stylizer = FakeStylizer(endpoint="https://abc.gradio.live/run")
    r, _, _ = runner(stylizer)
    job = new_job("u1", AvatarSource.SELFIE, {}, NOW)
    with pytest.raises(EndpointNotApproved):
        r.run(job, JPEG)
    assert stylizer.calls == []


def test_no_vendor_configured_by_default() -> None:
    with pytest.raises(StylizerError):
        NotConfiguredStylizer().generate("p", "a")


# ---------- the safety check ------------------------------------------------


def test_safety_rules() -> None:
    assert judge(GOOD, selfie=True, min_similarity=0.6).ok
    for change, reason in [
        ({"looks_under_18": True}, Rejection.CHILD_LOOKING),
        ({"nudity": True}, Rejection.NUDITY),
        ({"violence": True}, Rejection.VIOLENCE),
        ({"text_or_logo": True}, Rejection.TEXT_OR_LOGO),
        ({"face_count": 2}, Rejection.NO_FACE),
        ({"similarity": 0.4}, Rejection.NOT_THE_PERSON),
        ({"similarity": None}, Rejection.NOT_THE_PERSON),
    ]:
        verdict = judge(facts(**change), selfie=True, min_similarity=0.6)
        assert reason in verdict.reasons, change
    # Built avatars aren't compared with anyone.
    assert judge(facts(similarity=None), selfie=False, min_similarity=0.6).ok


# ---------- jobs -------------------------------------------------------------


def test_built_avatar_succeeds_and_records_its_cost() -> None:
    r, jobs, costs = runner()
    job = r.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert job.status is JobStatus.SUCCEEDED
    assert job.portrait_id is not None
    assert job.attempts == 1
    assert [(c.uid, c.job_id, c.usd) for c in costs.entries] == [("u1", job.id, 0.04)]
    assert jobs.get(job.id) == job


def test_a_child_looking_result_is_retried_once_then_a_kind_message() -> None:
    inspector = FakeInspector([facts(looks_under_18=True)])
    r, _, costs = runner(inspector=inspector)
    job = r.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert job.status is JobStatus.REJECTED
    assert job.attempts == 2
    assert job.message_id == Messages.NOT_MADE
    assert job.rejections == ["child_looking"]
    assert job.portrait_id is None
    assert len(costs.entries) == 2


def test_one_bad_attempt_then_a_good_one() -> None:
    inspector = FakeInspector([facts(text_or_logo=True), GOOD])
    r, _, _ = runner(inspector=inspector)
    job = r.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert (job.status, job.attempts) == (JobStatus.SUCCEEDED, 2)


def test_selfie_result_must_look_like_the_person() -> None:
    inspector = FakeInspector([facts(similarity=0.3)])
    stylizer = FakeStylizer()
    r, _, _ = runner(stylizer, inspector)
    job = r.run(new_job("u1", AvatarSource.SELFIE, {}, NOW), JPEG)
    assert job.status is JobStatus.REJECTED
    assert job.rejections == ["not_the_person"]
    # The selfie went to the approved stylizer as the reference only.
    assert all(ref == JPEG for _, _, ref in stylizer.calls)


def test_vendor_failures_retry_once_then_fail_kindly() -> None:
    r, _, costs = runner(FakeStylizer(fail_times=5))
    job = r.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert (job.status, job.message_id, job.attempts) == (
        JobStatus.FAILED,
        Messages.NOT_MADE,
        2,
    )
    assert costs.entries == []


def test_adjust_edits_the_approved_portrait() -> None:
    portraits = InMemoryPortraits()
    stylizer = FakeStylizer()
    r, _, _ = runner(stylizer, portraits=portraits)
    nothing = r.run(new_job("u1", AvatarSource.ADJUST, {"cap": "beanie"}, NOW))
    assert (nothing.status, nothing.message_id) == (
        JobStatus.FAILED,
        Messages.NO_PORTRAIT,
    )
    first = r.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert first.portrait_id
    _, image = portraits.latest("u1")  # type: ignore[misc]
    adjusted = r.run(new_job("u1", AvatarSource.ADJUST, {"cap": "beanie"}, NOW))
    assert adjusted.status is JobStatus.SUCCEEDED
    prompt, _, reference = stylizer.calls[-1]
    assert reference == image
    assert "Only change: a knit beanie" in prompt


# ---------- the HTTP API -----------------------------------------------------


def client(**settings: object) -> tuple[TestClient, Services, FakeStylizer]:
    stylizer = FakeStylizer()
    consents = FakeConsents({"u1": {"camera", "biometric"}})
    services = Services(
        settings=Settings(approved_hosts=APPROVED, **settings),  # type: ignore[arg-type]
        auth=FakeAuthenticator(),
        consents=consents,
        stylizer=stylizer,
        inspector=FakeInspector(),
        clock=lambda: NOW,
    )
    return TestClient(create_app(services)), services, stylizer


def headers(uid: str = "u1", **extra: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer token-{uid}",
        "X-Firebase-AppCheck": "app-check-ok",
        **extra,
    }


def selfie_body() -> dict[str, object]:
    return {"source": "selfie", "selfie_jpeg_base64": base64.b64encode(JPEG).decode()}


def test_needs_a_token_and_app_check() -> None:
    c, _, _ = client()
    assert c.post("/v1/avatar", json={"source": "built", "options": BUILT}).status_code == 401
    bad = {"Authorization": "Bearer token-u1", "X-Firebase-AppCheck": "nope"}
    assert c.get("/v1/avatar/jobs/x", headers=bad).status_code == 401


def test_build_my_own_end_to_end() -> None:
    c, _, _ = client()
    r = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers())
    assert r.status_code == 202
    job_id = r.json()["job_id"]
    status = c.get(f"/v1/avatar/jobs/{job_id}", headers=headers()).json()
    assert status["status"] == "succeeded"
    assert status["portrait_id"]


def test_someone_elses_job_is_not_found() -> None:
    c, _, _ = client()
    job_id = c.post(
        "/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers()
    ).json()["job_id"]
    assert c.get(f"/v1/avatar/jobs/{job_id}", headers=headers("u2")).status_code == 404


def test_unknown_options_are_refused_before_anything_is_spent() -> None:
    c, _, stylizer = client()
    r = c.post(
        "/v1/avatar", json={"source": "built", "options": {**BUILT, "skin": "x"}}, headers=headers()
    )
    assert (r.status_code, r.json()["detail"]) == (422, "bad_options")
    assert stylizer.calls == []


def test_from_my_photo_is_off_until_the_flag() -> None:
    c, _, stylizer = client()
    r = c.post("/v1/avatar", json=selfie_body(), headers=headers())
    assert (r.status_code, r.json()["detail"]) == (403, "feature_off")
    assert stylizer.calls == []


def test_from_my_photo_needs_camera_and_biometric_consent() -> None:
    c, services, stylizer = client(from_photo_enabled=lambda: True)
    r = c.post("/v1/avatar", json=selfie_body(), headers=headers("u2"))
    assert (r.status_code, r.json()["detail"]) == (403, "consent_required")
    assert stylizer.calls == []
    ok = c.post("/v1/avatar", json=selfie_body(), headers=headers("u1"))
    assert ok.status_code == 202
    job = services.jobs.get(ok.json()["job_id"])
    assert job is not None and job.status is JobStatus.SUCCEEDED
    # The photo itself is not kept with the job.
    stored = job.model_dump_json()
    assert "selfie-pixels" not in stored
    assert base64.b64encode(JPEG).decode() not in stored


@pytest.mark.parametrize(
    ("body", "detail"),
    [
        ({"source": "selfie"}, "selfie_required"),
        ({"source": "selfie", "selfie_jpeg_base64": "not base64!"}, "selfie_unreadable"),
        (
            {"source": "selfie", "selfie_jpeg_base64": base64.b64encode(b"PNG").decode()},
            "selfie_not_jpeg",
        ),
        (
            {
                "source": "built",
                "options": BUILT,
                "selfie_jpeg_base64": base64.b64encode(JPEG).decode(),
            },
            "selfie_only_for_selfie_source",
        ),
    ],
)
def test_selfie_uploads_are_checked(body: dict[str, object], detail: str) -> None:
    c, _, _ = client(from_photo_enabled=lambda: True)
    r = c.post("/v1/avatar", json=body, headers=headers())
    assert r.json()["detail"] == detail


def test_three_generations_a_day_from_remote_config() -> None:
    c, _, stylizer = client()
    for _ in range(3):
        r = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers())
        assert r.status_code == 202
    r = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers())
    assert (r.status_code, r.json()["detail"]) == (429, Messages.DAILY_LIMIT)
    assert len(stylizer.calls) == 3
    # Another person isn't affected; the limit follows Remote Config.
    assert (
        c.post(
            "/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers("u2")
        ).status_code
        == 202
    )
    c2, _, _ = client(daily_limit=lambda: 1)
    c2.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers())
    assert (
        c2.post(
            "/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers()
        ).status_code
        == 429
    )


def test_the_limit_resets_the_next_day() -> None:
    jobs = InMemoryJobs()
    for _ in range(3):
        jobs.add(new_job("u1", AvatarSource.BUILT, BUILT, NOW - timedelta(days=1)))
    assert jobs.count_on("u1", NOW.date()) == 0


def test_idempotent_with_a_key() -> None:
    c, _, stylizer = client()
    h = headers(**{"Idempotency-Key": "abc"})
    first = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=h)
    again = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=h)
    assert first.json()["job_id"] == again.json()["job_id"]
    assert len(stylizer.calls) == 1


def test_unconfigured_service_refuses_everyone() -> None:
    c = TestClient(create_app())
    r = c.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=headers())
    assert r.status_code == 401
