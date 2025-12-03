from __future__ import annotations
import os
import io
import asyncio
import aiohttp
import av
import uuid
from typing import Any
from livekit.agents import tts, utils
from livekit import rtc

class MurfTTS(tts.TTS):
    def __init__(self):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False), 
            sample_rate=24000, 
            num_channels=1
        )
        self.api_key = os.getenv("MURF_API_KEY")
        self.url = "https://api.murf.ai/v1/speech/stream" 

    def synthesize(
        self,
        text: str,
        *,
        conn_options: Any = None, 
    ) -> "MurfStream":
        return MurfStream(self, text, conn_options)


class MurfStream(tts.ChunkedStream):
    def __init__(
        self, 
        tts_instance: MurfTTS, 
        text: str, 
        conn_options: Any
    ):
        super().__init__(tts=tts_instance, input_text=text, conn_options=conn_options)
        self._tts = tts_instance

    async def _run(self, *args):
        request_id = str(uuid.uuid4())
        
        try:
            async with aiohttp.ClientSession() as session:
                payload = {
                    "voice_id": "en-US-matthew", 
                    "text": self._input_text,
                    "multi_native_locale": "en-US",
                    "model": "FALCON",
                    "format": "MP3",
                    "sampleRate": 24000,
                    "channelType": "MONO"
                }
                headers = {
                    "api-key": self._tts.api_key,
                    "Content-Type": "application/json"
                }

                async with session.post(self._tts.url, json=payload, headers=headers) as resp:
                    if resp.status != 200:
                        error_msg = await resp.text()
                        print(f"Murf API Error {resp.status}: {error_msg}")
                        return 

                    mp3_data = await resp.read()
                    
                    # FIX: Run decoding in a separate thread to avoid blocking the event loop
                    await asyncio.to_thread(self._decode_and_send_sync, mp3_data, request_id)

        except Exception as e:
            print(f"Murf Generation Exception: {e}")

    def _decode_and_send_sync(self, mp3_data, request_id):
        """
        Synchronous decoding running in a thread.
        Using send_nowait is safe here because the channel is thread-safe.
        """
        try:
            with av.open(io.BytesIO(mp3_data), mode='r') as container:
                stream = container.streams.audio[0]
                resampler = av.AudioResampler(
                    format='s16',
                    layout='mono',
                    rate=24000
                )

                for frame in container.decode(stream):
                    for resampled_frame in resampler.resample(frame):
                        pcm_bytes = resampled_frame.to_ndarray().tobytes()
                        
                        # Push audio frame
                        self._event_ch.send_nowait(
                            tts.SynthesizedAudio(
                                request_id=request_id, 
                                frame=rtc.AudioFrame(
                                    data=pcm_bytes, 
                                    sample_rate=24000, 
                                    num_channels=1, 
                                    samples_per_channel=len(pcm_bytes) // 2 
                                )
                            )
                        )
        except Exception as e:
            print(f"Audio Decoding Error: {e}")