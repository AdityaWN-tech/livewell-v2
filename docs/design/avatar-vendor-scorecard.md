# Avatar image method: scorecard (T-AVT-08c)

How we choose what makes the coach's 3D portrait and its frames (the `AvatarStylizer` adapter in `services/media`) and what checks every result (the `ImageInspector` behind the safety check). **Nothing is chosen yet**: the decision needs the product owner, and licences and data terms need legal review. Until then the service is configured with no vendor and refuses every call.

Every fact below about a vendor or model must be **verified against its current terms** before scoring; this page lists candidates, not endorsements (spec 8.3).

## Hard requirements (pass or fail, before any scoring)

1. **Commercial licence** for the model and every model it depends on. Several popular face models depend on **InsightFace** weights that are licensed for **non-commercial use only**; such a pipeline is out for prod unless we hold a commercial licence for those weights.
2. **Data terms:** no training on our users' photos; a deletion API (or no retention); a data processing agreement we can sign; India and US users.
3. **No public demo servers** (public Gradio, Hugging Face Spaces, Colab, tunnels): the service refuses them in code (`check_endpoint`), whatever the configuration.
4. **Adults only:** the method must hold "adult, real age" from the prompt and reference; our safety check rejects child-looking results either way.

## Scoring (1 to 5 each; weight in brackets)

| Criterion | What we measure in the spike |
|---|---|
| Likeness (25%) | From my photo: people who know the person recognise them (blind test, 20 consenting staff selfies); face-similarity score |
| Consistency with the reference (20%) | Matches `avatar-style-3d-reference.png`: 3D caricature, mint background, soft light; the same across all 8 coaches |
| Frame consistency (15%) | The 14 frames keep the same face, hair, clothes and position (T-AVT-08d); mouth frames change only the mouth |
| Speed (10%) | Time for one portrait and for a 14-frame set (target: portrait in 30–90 s) |
| Cost per avatar (15%) | One portrait plus 14 frames, with one retry |
| Data terms and licence clarity (15%) | Beyond the pass/fail above: retention period, sub-processors, region, audit |

## Candidates to evaluate (verify each)

| Kind | Candidates | Notes to check |
|---|---|---|
| Commercial image API with reference and editing | Google Vertex AI image generation and editing; OpenAI image editing; Black Forest Labs FLUX Kontext (API); Stability AI API | Reference-image and edit support, enterprise data terms, deletion, regions, price per image |
| Self-hosted on our GPU (Cloud Run GPU or GKE) | Open-weight base models with identity adapters (for example IP-Adapter FaceID, InstantID, PhotoMaker, PuLID) | **Licence of every weight**, especially InsightFace dependencies (non-commercial); GPU cost; who maintains it |
| Out of scope here | HeyGen, Tavus, D-ID, Synthesia (spec 8.3) | Photo-realistic **video**; Phase 2, not the 3D still frames |

## The safety check's model (`ImageInspector`)

Needs: one face; looks adult (reject under-18-looking); nudity; violence; text and logos; for From my photo, face similarity to the selfie (threshold `min_similarity`, default 0.6, tuned in the spike). Candidates to verify: Google Cloud Vision (safe search, text and logo detection); a commercially licensed face-similarity and age model (cloud APIs such as AWS Rekognition or Azure Face have their own access and terms). Face-similarity models built on InsightFace weights are non-commercial: same rule as above.

## Spike plan (about one week)

1. Shortlist 2 to 3 candidates that pass the hard requirements on paper.
2. Make the 8 ready-made coaches (prompts in `avatar-prompts.md` section C) and their 14 frames with each.
3. With written consent, make From my photo avatars for about 20 staff selfies; blind likeness test.
4. Score with the table above; record every model and licence in `asset-licences.md`.
5. The product owner decides; record it in `docs/decisions.md`; configure the adapter and the approved host.
