FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN python3.11 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
COPY src/ ./src/

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel build twine
RUN python -m pip install --no-cache-dir .

# Verify install
RUN python -m pip show echo-tts && python -c "from echo_tts import EchoTTS; print('Package installed successfully')"

# Build the distribution
RUN python -m build

ENTRYPOINT ["python", "-m", "echo_tts.cli"]
