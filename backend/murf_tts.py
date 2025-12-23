from __future__ import annotations
import os
import io
import asyncio
import aiohttp
import av
import uuid
import logging
from typing import Any
from livekit.agents import tts, utils
from livekit import rtc

logger = logging.getLogger("murf_tts")

class MurfTTS(tts.TTS):
    def __init__(self, config: dict | None = None):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False), 
            # We standardize on 24kHz for Falcon
            sample_rate=24000, 
            num_channels=1
        )
        self.api_key = os.getenv("MURF_API_KEY")
        self.url = "https://api.murf.ai/v1/speech/stream"
        self.config = config if config is not None else {}

    def synthesize(self, text: str, *, conn_options: Any = None) -> "MurfStream":
        return MurfStream(self, text, conn_options)

class MurfStream(tts.ChunkedStream):
    def __init__(self, tts_instance: MurfTTS, text: str, conn_options: Any):
        super().__init__(tts=tts_instance, input_text=text, conn_options=conn_options)
        self._tts = tts_instance

    async def _run(self, *args):
        # --- FIX 1: CLEAN INPUT TEXT ---
        # Replace newlines and excessive whitespace with single spaces.
        # This prevents the TTS engine from treating newlines as 'end of generation' markers.
        clean_text = " ".join(self._input_text.split())

        # Log the cleaned text to verify what is actually sent
        logger.info(f"🗣️  TTS INPUT (Cleaned): '{clean_text}'")

        await asyncio.sleep(0.02)
        request_id = str(uuid.uuid4())
        
        is_hindi = any("\u0900" <= char <= "\u097f" for char in clean_text)
        user_voice = self._tts.config.get("voice_id", "en-US-zion")
        
        if is_hindi:
            target_voice = "en-US-zion" 
            target_locale = "hi-IN"
        else:
            target_voice = user_voice
            target_locale = "en-US"

        try:
            async with aiohttp.ClientSession() as session:
                payload = {
                    "voice_id": target_voice,
                    "text": clean_text, # Use the sanitized text
                    "multi_native_locale": target_locale,
                    "model": "FALCON",
                    "format": "MP3",
                    "sampleRate": 24000,
                    "channelType": "MONO"
                }
                headers = {
                    "api-key": self._tts.api_key,
                    "Content-Type": "application/json"
                }

                # Added timeout to prevent hanging on long generations
                # FIX: Use ClientTimeout object instead of raw integer
                async with session.post(self._tts.url, json=payload, headers=headers, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                    if resp.status != 200:
                        error_msg = await resp.text()
                        logger.error(f"MURF API ERROR {resp.status}: {error_msg}")
                        await asyncio.sleep(1.0) 
                        return 

                    mp3_data = await resp.read()
                    
                    if mp3_data:
                        await asyncio.to_thread(self._decode_and_send_sync, mp3_data, request_id)

        except Exception as e:
            logger.error(f"Murf Exception: {e}")
            await asyncio.sleep(1.0) 

    def _decode_and_send_sync(self, mp3_data, request_id):
        """
        Decodes MP3 and batches into fixed 20ms frames for smooth playback.
        """
        try:
            # Configuration for 20ms frames at 24kHz
            SAMPLE_RATE = 24000
            CHANNELS = 1
            BYTES_PER_SAMPLE = 2 # 16-bit = 2 bytes
            # 20ms = 0.02 seconds. 
            # Samples per frame = 24000 * 0.02 = 480 samples
            # Bytes per frame = 480 * 2 = 960 bytes
            FRAME_SIZE_BYTES = int(SAMPLE_RATE * 0.02 * BYTES_PER_SAMPLE) 
            
            audio_buffer = bytearray()

            with av.open(io.BytesIO(mp3_data), mode='r') as container:
                stream = container.streams.audio[0]
                resampler = av.AudioResampler(format='s16', layout='mono', rate=SAMPLE_RATE)

                for frame in container.decode(stream):
                    for resampled_frame in resampler.resample(frame):
                        # Add new data to buffer
                        audio_buffer.extend(resampled_frame.to_ndarray().tobytes())

                        # While we have enough data for a full 20ms frame, send it
                        while len(audio_buffer) >= FRAME_SIZE_BYTES:
                            chunk = audio_buffer[:FRAME_SIZE_BYTES]
                            audio_buffer = audio_buffer[FRAME_SIZE_BYTES:]
                            
                            self._event_ch.send_nowait(
                                tts.SynthesizedAudio(
                                    request_id=request_id, 
                                    frame=rtc.AudioFrame(
                                        data=bytes(chunk), 
                                        sample_rate=SAMPLE_RATE, 
                                        num_channels=CHANNELS, 
                                        samples_per_channel=len(chunk) // BYTES_PER_SAMPLE
                                    )
                                )
                            )
            
            # --- FIX 2: FLUSH REMAINING BUFFER ---
            # If there is leftover audio (less than 20ms), pad it with silence and send it.
            if len(audio_buffer) > 0:
                padding_size = FRAME_SIZE_BYTES - len(audio_buffer)
                audio_buffer.extend(b'\x00' * padding_size) # Pad with silence (zeros)
                
                self._event_ch.send_nowait(
                    tts.SynthesizedAudio(
                        request_id=request_id, 
                        frame=rtc.AudioFrame(
                            data=bytes(audio_buffer), 
                            sample_rate=SAMPLE_RATE, 
                            num_channels=CHANNELS, 
                            samples_per_channel=len(audio_buffer) // BYTES_PER_SAMPLE
                        )
                    )
                )

        except Exception as e:
            logger.error(f"Decoding Error: {e}")