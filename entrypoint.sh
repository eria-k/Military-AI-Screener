#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

sha256sum_check() {
  local file="$1"
  local expected="${MODEL_SHA256:-}"
  if [ -n "$expected" ]; then
    log "Verifying SHA256 for $(basename "$file")"
    local actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    log "Expected: $expected"
    log "Actual:   $actual"
    if [ "$actual" != "$expected" ]; then
      echo "ERROR: SHA256 mismatch for $file" >&2
      exit 3
    fi
  fi
}

download_file() {
  local url="$1"
  local out="$2"
  log "Downloading: $url"
  DL_URL="$url" DL_OUT="$out" python - <<'PY'
import os, urllib.request, sys
url = os.environ['DL_URL']
out = os.environ['DL_OUT']
urllib.request.urlretrieve(url, out)
print("Saved to:", out)
PY
}

MODEL_PATH="${MODEL_PATH:-/app/military_screening_cnn.h5}"

log "Boot preflight..."
log "Python: $(python --version || true)"
log "Whoami: $(whoami || true)"
log "Working dir: $(pwd)"

# Preflight: if model is missing AND no URLs are set, fail clearly
if [ ! -f "$MODEL_PATH" ] && [ -z "${MODEL_ARCHIVE_URL:-}" ] && [ -z "${MODEL_URL:-}" ]; then
  echo "ERROR: Model missing at $MODEL_PATH and neither MODEL_ARCHIVE_URL nor MODEL_URL is set." >&2
  exit 5
fi

# Ensure model exists one way or another
if [ ! -f "$MODEL_PATH" ]; then
  if [ -n "${MODEL_ARCHIVE_URL:-}" ]; then
    ARCHIVE_PATH="/app/model.7z"
    log "Model not found. Downloading 7z archive from: $MODEL_ARCHIVE_URL"
    download_file "$MODEL_ARCHIVE_URL" "$ARCHIVE_PATH"
    sha256sum_check "$ARCHIVE_PATH"
    log "Extracting archive to /app ..."
    if [ -n "${MODEL_ARCHIVE_PASSWORD:-}" ]; then
      7z x -y -p"$MODEL_ARCHIVE_PASSWORD" -o/app "$ARCHIVE_PATH"
    else
      7z x -y -o/app "$ARCHIVE_PATH"
    fi
    log "Extraction complete."
    if [ ! -f "$MODEL_PATH" ]; then
      CANDIDATE=$(find /app -maxdepth 2 -type f -name "*.h5" | head -n 1 || true)
      if [ -n "$CANDIDATE" ]; then
        log "Detected model at $CANDIDATE"
        export MODEL_PATH="$CANDIDATE"
      else
        echo "ERROR: Could not find any .h5 after extracting the archive." >&2
        exit 4
      fi
    fi
  elif [ -n "${MODEL_URL:-}" ]; then
    log "Model not found. Downloading raw model from: $MODEL_URL"
    download_file "$MODEL_URL" "$MODEL_PATH"
    sha256sum_check "$MODEL_PATH"
  fi
fi

log "Starting gunicorn on port ${PORT:-8000}..."
exec gunicorn --bind 0.0.0.0:${PORT:-8000} --workers 2 --threads 4 --timeout 120 app:app
