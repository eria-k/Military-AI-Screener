# Military AI Pre‑Screening — Render Deployment

This repo is configured for **Render** (Docker). It supports **downloading and extracting a 7z-compressed model** at runtime, so you don't commit the large `.h5` to Git.

## Project layout
```
.
├─ app.py                   # Flask API (/, /health, /predict)
├─ templates/
│  └─ index.html            # UI (moved here for Flask to find it)
├─ scaler.pkl               # small, kept in git
├─ label_encoder.pkl        # small, kept in git
├─ military_knowledge_graph.pkl
├─ requirements.txt
├─ Dockerfile               # installs p7zip-full; uses gunicorn
├─ entrypoint.sh            # downloads & extracts model before start
├─ scripts/
│  └─ download_model.py     # download helper
├─ Procfile                 # optional non-Docker
├─ .dockerignore            # excludes .7z/.h5 etc. from image build context
└─ render.yaml              # optional Render IaC (set env vars)
```

## Deploy on Render (Docker)
1. Push this repo to **GitHub** (do NOT include `.h5` or `.7z`).
2. On **Render** → **New +** → **Web Service** → Connect the GitHub repo.
3. Render detects the **Dockerfile** and builds the image.
4. In **Environment** (Render dashboard), set variables:
   - `MODEL_ARCHIVE_URL` → direct link to your `model.7z`
   - `MODEL_SHA256` → optional checksum of the archive
   - `MODEL_ARCHIVE_PASSWORD` → only if you protected it
   - `MODEL_PATH` → `/app/military_screening_cnn.h5` (default)
   - `PORT` → `8000` (Render passes this automatically too)
5. Deploy. Health endpoint: `/health`

## API
`POST /predict` → `{ "sensor_data": [561 floats] }`  
Response includes `activity`, `confidence`, biomarkers, roles, and `PASS/CONDITIONAL PASS/FAIL` decision.

## Notes
- If you get `Expected 561 features`, your payload length is wrong.
- The app loads: `.h5` model (downloaded at startup), `scaler.pkl`, `label_encoder.pkl`, `military_knowledge_graph.pkl`.
- 502/timeout issues are mitigated with gunicorn `--timeout 120`. Increase if your model is slow.
