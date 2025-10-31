
# Military AI Pre-Screening — Deployment Guide

This bundle contains everything you need to deploy your Flask+TensorFlow model with Docker.

## Files
- `app.py` — Flask app (serves `/`, `/health`, `/predict`)
- `templates/index.html` — Frontend UI (moved to Flask default)
- `military_screening_cnn.h5` — Trained CNN model (HAR)
- `scaler.pkl`, `label_encoder.pkl`, `military_knowledge_graph.pkl` — Preprocessing + KG
- `requirements.txt` — Cleaned (removed `p7zip-full`, which is an apt package)
- `Dockerfile` — Containerized deployment (recommended)
- `.dockerignore` — Keeps image small
- `Procfile` — For non-Docker platforms (optional)

> Note: The app expects **561 features** in `sensor_data`. See `/predict` implementation.

## Quick Local Test (Docker)
```bash
docker build -t military-screening .
docker run -p 8000:8000 -e PORT=8000 military-screening
# Open http://localhost:8000
```

## Render (recommended, Docker)
1. Push these files to a Git repo (GitHub).
2. On Render:
   - **New +** → **Web Service** → **Build from repo**
   - Environment: **Docker**
   - Region: closest to you
   - Expose port: **8000** (Render auto-detects from logs; PORT env is set)
3. Deploy. Health endpoint: `/health`

## Railway (Docker)
1. New Project → Deploy from repo → **Dockerfile** detected
2. Set `PORT=8000` in variables (Railway sometimes injects its own)
3. Deploy.

## Non-Docker (Heroku / Railway Nixpacks)
- Ensure `requirements.txt` is present
- Add `Procfile`
- Set `PORT` env var (Heroku injects it)
- Deploy

## Common 502 Fixes
- **Templates**: We moved `index.html` into `templates/` so `render_template('index.html')` works.
- **Model load**: `app.py` now loads `.h5` and `.pkl` at startup. If large, first request may wait; platform should keep dyno warm.
- **Timeouts**: Gunicorn timeout is set to **120s**.
- **TensorFlow size**: Use Docker to avoid build errors on PaaS.

## API contract
`POST /predict`
```json
{ "sensor_data": [561 floats] }
```
Response
```json
{
  "success": true,
  "prediction": {
    "activity": "WALKING",
    "confidence": 0.87,
    "decision": "PASS",
    "reason": "Excellent movement quality and form",
    "risk_level": "LOW",
    "recommended_roles": ["Infantry","Special Forces","Combat Engineer"],
    "biomarkers": {
      "movement_quality": 0.87,
      "fatigue_index": 0.05,
      "movement_smoothness": 0.883
    }
  }
}
```

## Notes
- We removed the `p7zip` dependency from `requirements.txt`. If you need to extract a `.7z` at runtime, prefer Docker + `apt-get install p7zip-full` **in the Dockerfile**. The current code skips extraction because the `.h5` is already present.
- If you see `Expected 561 features` errors, make sure the frontend sends the correct array length.
- For very slow cold starts, increase workers/threads cautiously (memory!).



---

## Deploying without committing the big `.h5` to Git

You have 3 good options:

### Option A — Download at runtime (simplest)
Host the model file somewhere (e.g., **S3 pre-signed URL**, **GCS signed URL**, **GitHub Release asset**, **Dropbox direct link**, etc.).  
Then set these **environment variables** in your hosting platform:
- `MODEL_URL` — direct link to the `.h5`
- `MODEL_SHA256` — (optional) checksum to verify integrity
- `MODEL_PATH` — where to save it in the container (defaults to `/app/military_screening_cnn.h5`)

The container’s `entrypoint.sh` will download the model on start if it’s missing.

### Option B — Bake the model into the image (build-time)
If your host supports Docker builds with internet access, you can add a build ARG and download during the build so the image **contains the model**:
```
# Example (not enabled by default)
# ARG MODEL_URL
# RUN curl -L "$MODEL_URL" -o /app/military_screening_cnn.h5
```
This avoids runtime download but increases image size.

### Option C — Build image locally and push to a registry
1. Keep the `.h5` locally next to the Dockerfile.  
2. `docker build -t yourname/military-screening:latest .`  
3. `docker push yourname/military-screening:latest`  
4. In Render/Railway, deploy using **existing image from registry**.  
This way you never upload the model to Git.

### Recommended hosting for the model
- **AWS S3** (pre-signed URL)  
- **Google Cloud Storage** (signed URL)  
- **GitHub Releases** asset (not in git history; up to 2 GB per file)  
- **Dropbox** direct link (append `?dl=1`)

**Security tip:** Prefer time-limited signed URLs or keep the bucket private and rotate the URL when needed.


### Using a compressed 7z model (recommended for Git-friendly deploys)

You can compress your `military_screening_cnn.h5` into a `.7z` (e.g., 21 MB) and host it externally.  
Set these env vars on your host:

- `MODEL_ARCHIVE_URL` — direct link to the `.7z`
- `MODEL_ARCHIVE_PASSWORD` — only if you password-protected the archive
- `MODEL_SHA256` — SHA256 of the **archive** (optional but recommended)
- `MODEL_PATH` — where the extracted `.h5` should be (defaults to `/app/military_screening_cnn.h5`)

At startup, the container will download the `.7z`, verify (if SHA provided), and **extract** it with `7z`.
If `MODEL_PATH` doesn’t exist after extraction, it will auto-detect the first `.h5` found in `/app`.

**Generate SHA256 locally:**
```bash
sha256sum model.7z
```

**Create a 7z locally (no password):**
```bash
7z a model.7z military_screening_cnn.h5
```

**Create a 7z with password:**
```bash
7z a -p'StrongPassword!' model.7z military_screening_cnn.h5
```

Tip: Host the archive on **S3/GCS with a signed URL** or as a **GitHub Release** asset (not in Git).
