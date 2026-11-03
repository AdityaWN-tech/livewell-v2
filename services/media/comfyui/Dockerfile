# Our ComfyUI server for Cloud Run with an NVIDIA L4 (docs/media/comfyui-setup.md).
# The models are not in the image: they are read from a Cloud Storage volume
# mounted at /models (downloaded once from Hugging Face, see download_models.py).
# Build from the repository root:
#   docker build -f services/media/comfyui/Dockerfile \
#     --build-arg COMFYUI_REF=<commit> --build-arg GGUF_REF=<commit> -t comfyui .
# Pin both refs to reviewed commits; there is deliberately no default.
FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime

ARG COMFYUI_REF
ARG GGUF_REF
RUN test -n "$COMFYUI_REF" && test -n "$GGUF_REF"

RUN apt-get update && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone https://github.com/comfyanonymous/ComfyUI.git \
 && git -C ComfyUI checkout "$COMFYUI_REF" \
 && pip install --no-cache-dir -r ComfyUI/requirements.txt \
 && git clone https://github.com/city96/ComfyUI-GGUF.git ComfyUI/custom_nodes/ComfyUI-GGUF \
 && git -C ComfyUI/custom_nodes/ComfyUI-GGUF checkout "$GGUF_REF" \
 && pip install --no-cache-dir -r ComfyUI/custom_nodes/ComfyUI-GGUF/requirements.txt

COPY services/media/comfyui/livewell_forget ComfyUI/custom_nodes/livewell_forget
COPY services/media/comfyui/extra_model_paths.yaml ComfyUI/extra_model_paths.yaml

# Images in and out live in /tmp: on Cloud Run that is memory, wiped when
# the instance stops. The add-on above deletes each job's files at once.
RUN useradd --create-home comfy && mkdir -p /tmp/comfy && chown comfy /tmp/comfy
USER comfy
ENV PORT=8080
CMD exec python /opt/ComfyUI/main.py --listen 0.0.0.0 --port "$PORT" \
    --disable-auto-launch --dont-print-server \
    --input-directory /tmp/comfy/input --output-directory /tmp/comfy/output \
    --temp-directory /tmp/comfy
