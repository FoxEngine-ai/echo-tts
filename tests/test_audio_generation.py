import os
from pathlib import Path

import pytest
import torch
import torchaudio

from echo_tts import EchoTTS

RUN_ENV = "ECHO_TTS_RUN_AUDIO_TEST"
OUTPUT_ENV = "ECHO_TTS_TEST_OUTPUT_DIR"
DEVICE_ENV = "ECHO_TTS_TEST_DEVICE"
STEPS_ENV = "ECHO_TTS_TEST_STEPS"
SEQ_ENV = "ECHO_TTS_TEST_SEQUENCE_LENGTH"


def _select_dtype(device: str) -> torch.dtype:
    if device == "cuda":
        if hasattr(torch.cuda, "is_bf16_supported") and torch.cuda.is_bf16_supported():
            return torch.bfloat16
        return torch.float16
    return torch.float32


@pytest.mark.skipif(
    os.getenv(RUN_ENV) != "1",
    reason=f"Set {RUN_ENV}=1 to run the audio generation test.",
)
def test_generates_wav_in_output_dir():
    device = os.getenv(DEVICE_ENV, "cuda")
    if device == "cuda" and not torch.cuda.is_available():
        pytest.skip("CUDA not available; set ECHO_TTS_TEST_DEVICE=cpu to run on CPU.")

    output_dir = Path(os.getenv(OUTPUT_ENV, "output"))
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        pytest.skip(
            f"Output directory '{output_dir}' is not writable; set {OUTPUT_ENV} to a writable path."
        )

    output_path = output_dir / "test_generated.wav"
    if output_path.exists():
        output_path.unlink()

    steps = max(1, int(os.getenv(STEPS_ENV, "4")))
    sequence_length = max(32, int(os.getenv(SEQ_ENV, "128")))

    tts = EchoTTS(device=device, dtype=_select_dtype(device), compile=False)
    audio, sr = tts.synthesize(
        text="Hello from Echo TTS.",
        seed=0,
        num_steps=steps,
        sequence_length=sequence_length,
    )

    assert audio.numel() > 0
    assert torch.isfinite(audio).all()
    assert audio.abs().max().item() > 0

    tts.save(audio, str(output_path), sr)

    assert output_path.exists()
    assert output_path.stat().st_size > 44

    loaded, loaded_sr = torchaudio.load(str(output_path))
    assert loaded_sr == sr
    assert loaded.numel() > 0
    assert loaded.abs().max().item() > 0
