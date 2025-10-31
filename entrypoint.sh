#!/usr/bin/env bash
set -euo pipefail

sha256sum_check() {
  local file="$1"
  local expected="${MODEL_SHA256:-}"
  if [ -n "$expected" ]; then
    echo "Verifying SHA256 for $(basename "$file")..."
    local actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    echo "Expected: $expected"
    echo "Actual:   $actual"
    if [ "$actual" != "$expected" ]; then
      echo "ERROR: SHA256 mismatch for $file" >&2
      exit 3
    fi
  fi
}

download_file() {
  local url="$1"
  local out="$2"
  echo "Downloading: $url"
  python - <<PY
import urllib.request, sys
url = sys.argv[1]
out = sys.argv[2]
urllib.request.urlretrieve(url, out)
print("Saved to:", out)
PY
}

MODEL_PATH="${MODEL_PATH:-/app/military_screening_cnn.h5}"

if [ ! -f "$MODEL_PATH" ]; then
  if [ -n "${MODEL_ARCHIVE_URL:-}" ]; then
    ARCHIVE_PATH="/app/model.7z"
    echo "Model not found. Will download 7z archive: $MODEL_ARCHIVE_URL"
    download_file "$MODEL_ARCHIVE_URL" "$ARCHIVE_PATH"
    sha256sum_check "$ARCHIVE_PATH"
    echo "Extracting archive to /app ..."
    if [ -n "${MODEL_ARCHIVE_PASSWORD:-}" ]; then
      7z x -y -p"$MODEL_ARCHIVE_PASSWORD" -o/app "$ARCHIVE_PATH"
    else
      7z x -y -o/app "$ARCHIVE_PATH"
    fi
    echo "Extraction complete."
    if [ ! -f "$MODEL_PATH" ]; then
      CANDIDATE=$(find /app -maxdepth 2 -type f -name "*.h5" | head -n 1 || true)
      if [ -n "$CANDIDATE" ]; then
        echo "Detected model at $CANDIDATE"
        export MODEL_PATH="$CANDIDATE"
      else
        echo "ERROR: Could not find any .h5 after extracting the archive." >&2
        exit 4
      fi
    fi
  elif [ -n "${MODEL_URL:-}" ]; then
    echo "Model not found. Downloading raw model from: $MODEL_URL"
    download_file "$MODEL_URL" "$MODEL_PATH"
    sha256sum_check "$MODEL_PATH"
  else
    echo "WARNING: MODEL_URL / MODEL_ARCHIVE_URL not set and model file missing at $MODEL_PATH."
    echo "The app may fail to load the model."
  fi
fi

# Start gunicorn
exec gunicorn --bind 0.0.0.0:${PORT:-8000} --workers 2 --threads 4 --timeout 120 app:app
