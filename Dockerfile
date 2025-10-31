FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# System deps for sklearn + 7z extractor
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt


# Copy app source
COPY . .

# Default envs
ENV PORT=8000
ENV MODEL_PATH=/app/military_screening_cnn.h5
# ENV MODEL_ARCHIVE_URL=
# ENV MODEL_ARCHIVE_PASSWORD=
# ENV MODEL_URL=
# ENV MODEL_SHA256=

# Normalize line endings and ensure executable bit for entrypoint
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Launch entrypoint explicitly with bash to avoid sh-incompatibilities
ENTRYPOINT ["/bin/bash","/app/entrypoint.sh"]

