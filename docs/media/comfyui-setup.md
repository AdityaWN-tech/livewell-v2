# Running our ComfyUI server on a Google Cloud GPU

The Media Service makes coach portraits and the 14 frames with **our own ComfyUI server**, using open models downloaded from Hugging Face (all Apache-2.0, listed in [asset-licences.md](../design/asset-licences.md)). This guide sets ComfyUI up as a **private Cloud Run service with one NVIDIA L4 GPU that scales to zero when idle**.

```
Phone ──HTTPS──▶ Media Service (Cloud Run, CPU) ──ID token──▶ ComfyUI (Cloud Run, L4 GPU, private)
                     │                                             │
                     │ safety check, alignment, storage            └── models: Cloud Storage volume (read-only)
                     ▼
              Cloud Storage avatars/{uid}/{version}/
```

- **The phone never talks to ComfyUI or Hugging Face.** Only the Media Service calls ComfyUI.
- **User photos never go to public Spaces, Gradio links, Colab or tunnels.** The service refuses those hosts in code (`check_endpoint`), even if one is approved by mistake.
- **No photo is kept on the ComfyUI server.** After each image, the Media Service asks ComfyUI to delete the input, the output and the job's history (the `livewell_forget` add-on). The disk is in memory and is wiped when the instance stops.
- **Secrets** (the ComfyUI URL, an API key if used, the Hugging Face token) live in **Secret Manager**, never in the repo or the image.

## 0. Before you start: billing (the Blaze plan decision)

**Cloud Run GPUs need billing turned on.** The project is on the free Spark plan today (D-17), and nothing in this guide can be deployed until the owner switches it to **Blaze (pay as you go)** and links a billing account. This is the same decision that unlocks the Media Service, Secret Manager and Cloud Storage uploads. Set a **budget alert** (for example $50 a month) in Billing > Budgets & alerts at the same time.

Also check:

- **GPU quota:** the first deployment with an L4 in a region automatically gets a quota of **3 L4 GPUs** (with zonal redundancy off). More needs a quota request.
- **Region:** L4 is available in `us-central1`, `us-east4`, `europe-west1`, `europe-west4`, `asia-southeast1` and `asia-south1` (Mumbai, by invitation only). Our Firestore is in the US (nam5, D-14), so use **`us-central1`** for both the Media Service and ComfyUI.
- **Billing model:** GPU services must use **instance-based billing**: you pay for the whole time an instance is up, including idle time before it scales down. **Min instances 0** means nothing is billed when there are no jobs. Min instances 1 avoids cold starts but is billed all day.

## 1. Will it fit on one L4? (the memory plan)

An L4 has **24 GB of GPU memory**. Cloud Run gives a GPU instance at most **32 GiB of RAM** (minimum 4 CPU / 16 GiB, recommended 8 CPU / 32 GiB).

| Model | bf16 | fp8 | GGUF Q5_K_M | GGUF Q4_K_M |
|---|---|---|---|---|
| Qwen-Image (text-to-image, 20B) | 40.9 GB | 20.4 GB | about 15 GB | about 13 GB |
| Qwen-Image-Edit-2511 (edit, 20B) | 40.9 GB | 20.4 GB | **15.0 GB** | 13.2 GB |
| Qwen2.5-VL 7B text encoder (both use it) | 16.6 GB | **9.38 GB** | — | — |
| VAE + Lightning LoRA | | **about 1.1 GB** | | |

**Answer: Qwen-Image and Qwen-Image-Edit don't both fit on one L4**, not even at fp8 (2 × 20.4 GB). Even **one** fp8 model plus the fp8 text encoder (about 30 GB) is more than the GPU holds and too close to the 32 GiB RAM limit. So:

- **We use one model for everything: Qwen-Image-Edit-2511, GGUF Q5_K_M (15.0 GB)**, with the fp8 text encoder (9.38 GB) and the 4-step Lightning LoRA. The selfie, Adjust and every frame are edits of an image. **Build my own** uses the same model with no input image (text only), so nothing has to swap between jobs.
- ComfyUI keeps the diffusion model on the GPU and moves the text encoder between GPU and RAM for each image (about 25 GB of RAM in use, under the 32 GiB limit).
- If an instance runs out of memory, switch to **Q4_K_M (13.2 GB)**: change the file name in both workflow files and in the model list.
- **Qwen-Image for Build my own** (if the scorecard shows it looks better than the Edit model in text mode) needs either a second ComfyUI service with its own L4, or a bigger GPU: an **RTX PRO 6000 (96 GB)** holds both models at fp8 or bf16 (minimum 20 CPU / 80 GiB; `us-central1`, `europe-west4`, `asia-southeast1`, `asia-south2`).

## 2. How long does one coach take?

One coach is **15 images**: the portrait, then the 14 frames (neutral from the portrait, the other 13 from neutral), each one ComfyUI job. A frame that fails the check is made once more.

There is no published L4 benchmark for this setup yet, so this is an **estimate to confirm in the spike**: an RTX 5090 makes one 4-step fp8 Qwen-Image-Edit image (about 1 MP) in about 6 seconds; an L4 has about a quarter to a fifth of its compute and a sixth of its memory speed, and the GGUF model and the text-encoder swap add some more. That gives about **30–45 seconds per image** on a warm L4.

| | Time |
|---|---|
| One image (warm) | about 30–45 s |
| Portrait + 14 frames (warm) | **about 8–11 minutes** |
| Cold start (instance starts, loads about 25 GB of models from Cloud Storage) | about 2–4 minutes more |

**That is far more than 90 seconds,** so the app doesn't keep people waiting on the camera screen. After the photo is sent it says **"We'll let you know when your coach is ready."** and the person can carry on. When the job ends, a notification says **"Your coach is ready"** (or that it couldn't be made); the words are generic, with no name or photo. While the app is open it checks the job itself and shows the notification; the server's push (`JobNotifier`, FCM) covers a closed app once FCM is wired at deploy.

**Ways to make it faster later** (none built yet): make the 13 frames in parallel on up to 3 instances (the default quota; about 3 minutes), use an RTX PRO 6000 with the fp8 model kept loaded, or keep one instance warm at busy times (billed while idle).

Record real timings in [avatar-vendor-scorecard.md](../design/avatar-vendor-scorecard.md) during the spike.

## 3. What it costs

Cloud Run bills the GPU, CPU and memory **per second while an instance is up** (instance-based billing). Look up the current `us-central1` rates on the [Cloud Run pricing page](https://cloud.google.com/run/pricing) (NVIDIA L4, **no zonal redundancy**, which is cheaper; plus 8 vCPU and 32 GiB of memory) and add them up into one rate per second:

```
cost of one coach ≈ (seconds the instance is up for the job) × (L4 + 8 vCPU + 32 GiB rate per second)
```

For example, 10 minutes of work plus the time before the instance scales down. Put the combined rate in `MEDIA_COMFYUI_USD_PER_SECOND` so each image's cost lands in the cost records (spec 8.4). The 3-a-day limit per person (`avatar_daily_generations`) caps the spend per person.

## 4. Set it up, step by step

Run these in Cloud Shell (or with the `gcloud` CLI), in the dev project first. Replace `PROJECT` with the project id.

**4.1 Turn on the services**

```
gcloud config set project PROJECT
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  cloudbuild.googleapis.com secretmanager.googleapis.com storage.googleapis.com
```

**4.2 Two service accounts** (one identity per service, least privilege)

```
gcloud iam service-accounts create comfyui --display-name "ComfyUI (GPU)"
gcloud iam service-accounts create media --display-name "Media Service"
```

**4.3 A bucket for the models** (models only: never photos)

```
gcloud storage buckets create gs://PROJECT-comfyui-models --location us-central1 \
  --uniform-bucket-level-access
gcloud storage buckets add-iam-policy-binding gs://PROJECT-comfyui-models \
  --member serviceAccount:comfyui@PROJECT.iam.gserviceaccount.com --role roles/storage.objectViewer
```

**4.4 Download the models from Hugging Face** (on a machine with about 30 GB free, for example Cloud Shell's ephemeral mode or a small VM)

1. Create a **read-only** token on Hugging Face (Settings > Access Tokens) and store it as a secret:
   ```
   printf %s "hf_..." | gcloud secrets create hf-token --data-file=-
   ```
2. Download (the script refuses any model that isn't cleared for commercial use) and copy to the bucket:
   ```
   pip install "huggingface_hub>=0.25"
   HF_TOKEN=$(gcloud secrets versions access latest --secret hf-token) \
     python services/media/comfyui/download_models.py ./models
   gcloud storage cp -r ./models/* gs://PROJECT-comfyui-models/
   ```
   You should see `unet/`, `text_encoders/`, `vae/` and `loras/` in the bucket.

**4.5 Build the ComfyUI image** (pin ComfyUI and ComfyUI-GGUF to reviewed commits)

```
gcloud artifacts repositories create livewell --repository-format docker --location us-central1
gcloud builds submit --region us-central1 --config services/media/comfyui/cloudbuild.yaml \
  --substitutions _COMFYUI_REF=<comfyui commit>,_GGUF_REF=<comfyui-gguf commit>,_TAG=1 .
```

The image has ComfyUI, the GGUF loader and our `livewell_forget` add-on, but **no models** (they come from the bucket).

**4.6 Deploy ComfyUI: private, one L4, scales to zero**

```
gcloud run deploy comfyui \
  --image us-central1-docker.pkg.dev/PROJECT/livewell/comfyui:1 \
  --region us-central1 \
  --service-account comfyui@PROJECT.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --gpu 1 --gpu-type nvidia-l4 --no-gpu-zonal-redundancy \
  --cpu 8 --memory 32Gi --no-cpu-throttling \
  --min-instances 0 --max-instances 1 \
  --concurrency 8 --timeout 900 --session-affinity \
  --add-volume name=models,type=cloud-storage,bucket=PROJECT-comfyui-models,readonly=true \
  --add-volume-mount volume=models,mount-path=/models \
  --startup-probe tcpSocket.port=8080,initialDelaySeconds=10,periodSeconds=10,failureThreshold=30
```

- `--no-allow-unauthenticated`: only callers with the **Cloud Run Invoker** role can reach it (next step). Nobody on the internet can.
- `--max-instances 1`: one GPU. Every request for one image (upload, job, download) must reach the same instance, because the images live in that instance's memory. With one instance that is always true. Raising it later needs session affinity (`--session-affinity`, already set; the Media Service keeps one connection with its cookie per image), and affinity is best effort, so test it first.
- `--min-instances 0`: scales to zero when idle. Cold starts take a few minutes (the probe allows 5).

**4.7 Let only the Media Service call it** (service-to-service identity, the main option)

```
gcloud run services add-iam-policy-binding comfyui --region us-central1 \
  --member serviceAccount:media@PROJECT.iam.gserviceaccount.com --role roles/run.invoker
```

The Media Service gets a **Google ID token** for the ComfyUI URL from the Cloud Run metadata server (`GoogleIdToken`, renewed before it expires) and sends it as `Authorization: Bearer`.

**4.8 Point the Media Service at it** (the URL is a secret too)

```
URL=$(gcloud run services describe comfyui --region us-central1 --format 'value(status.url)')
printf %s "$URL" | gcloud secrets create comfyui-url --data-file=-
gcloud secrets add-iam-policy-binding comfyui-url \
  --member serviceAccount:media@PROJECT.iam.gserviceaccount.com --role roles/secretmanager.secretAccessor
gcloud run deploy media ... \
  --service-account media@PROJECT.iam.gserviceaccount.com \
  --set-secrets MEDIA_COMFYUI_URL=comfyui-url:latest \
  --set-env-vars MEDIA_COMFYUI_AUTH=id_token,MEDIA_APPROVED_HOSTS=<host of $URL>,MEDIA_COMFYUI_USD_PER_SECOND=<rate>
```

The host has to be in `MEDIA_APPROVED_HOSTS` as well (for example `comfyui-abc123-uc.a.run.app`), or the Media Service refuses to send anything. Both settings have to agree, so a wrong secret can't send photos somewhere new.

| Setting | Where | What |
|---|---|---|
| `MEDIA_COMFYUI_URL` | Secret Manager (`comfyui-url`) | The ComfyUI service URL. Not set: the stylizer isn't configured and every job is refused kindly. |
| `MEDIA_APPROVED_HOSTS` | Env | Comma-separated hosts photos may go to. |
| `MEDIA_COMFYUI_AUTH` | Env | `id_token` (main) or `api_key` (fallback). |
| `MEDIA_COMFYUI_API_KEY` | Secret Manager | Only for the fallback. |
| `MEDIA_COMFYUI_API_KEY_HEADER` | Env | Default `X-Api-Key`. |
| `MEDIA_COMFYUI_TIMEOUT_S` | Env | Longest wait for one image, queue included (default 600). |
| `MEDIA_COMFYUI_USD_PER_SECOND` | Env | For the cost records (section 3). |

**Fallback: an API key.** If ComfyUI ever runs outside Cloud Run (for example on a GPU VM), put it behind a gateway that checks a key header and only serves HTTPS, store the key in Secret Manager, and set `MEDIA_COMFYUI_AUTH=api_key` with `--set-secrets MEDIA_COMFYUI_API_KEY=comfyui-key:latest`. **Never** expose ComfyUI itself to the internet: it has no login of its own.

## 5. Check it works (with a stock picture, never a user's photo)

```
TOKEN=$(gcloud auth print-identity-token --audiences "$URL")   # needs run.invoker for your own account
curl -H "Authorization: Bearer $TOKEN" "$URL/system_stats"      # first call wakes it (a few minutes)
```

Then run the Media Service tests locally (`services/media/README.md`), and one Build my own job in dev. Check that:

- the job's cost records appear and the timing matches section 2 (write it in the scorecard);
- `gs://PROJECT-comfyui-models` holds only models;
- in the ComfyUI logs there are no prompts or file names from our side (the service logs job ids and timings only).

## 6. Privacy checklist (before "From my photo" is switched on)

- [ ] ComfyUI is private (`--no-allow-unauthenticated`), invoker is only the Media Service account.
- [ ] `MEDIA_APPROVED_HOSTS` lists only the ComfyUI host.
- [ ] The `livewell_forget` add-on is in the image (a job's input and output are gone from `/tmp/comfy` straight after).
- [ ] No Cloud Storage volume is mounted for ComfyUI's input or output folders (they must stay in memory).
- [ ] Face similarity and age checks: a commercially licensed option is chosen and reviewed ([asset-licences.md](../design/asset-licences.md)). **Until then the `avatar_from_photo` flag stays off.** Build my own and the ready-made coaches don't depend on it.
- [ ] Counsel review (T-CMP-02).

## Troubleshooting

| What you see | Why, and what to do |
|---|---|
| Every job says "We couldn't make your coach" at once | The host isn't in `MEDIA_APPROVED_HOSTS`, or `MEDIA_COMFYUI_URL` isn't set. The Media Service logs `stylizer endpoint not approved`. |
| `403` from ComfyUI | The Media Service account is missing `roles/run.invoker` on the ComfyUI service. |
| Jobs time out on the first try of the day | Cold start. Raise `MEDIA_COMFYUI_TIMEOUT_S`, or keep `--min-instances 1` at busy times (billed while idle). |
| The instance restarts with out-of-memory | Switch to the Q4_K_M model (section 1). |
| `ComfyUI refused the workflow (400)` | A node or model name doesn't match the server: check the ComfyUI and ComfyUI-GGUF commits and the file names in the bucket. Re-export the graphs from ComfyUI's Qwen-Image-Edit template if nodes changed. |
