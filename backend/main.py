import logging
import os
import asyncio
from dotenv import load_dotenv
from livekit.agents import (
    AutoSubscribe,
    JobContext,
    WorkerOptions,
    cli,
    Agent,        
    AgentSession, 
)
from livekit.plugins import deepgram, openai, silero
from livekit import rtc
from murf_tts import MurfTTS  

load_dotenv()
logger = logging.getLogger("voice-agent")

async def entrypoint(ctx: JobContext):
    logger.info(f"Connecting to room {ctx.room.name}")
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)

    # Shared State for Voice Selection
    voice_state = {"voice_id": "en-US-zion"}

    participant_agent = Agent(
        instructions=(
            "You are 'Neo', a smart travel companion for Northeast India created by Team Neo Nomads. "
            "You are fully bilingual in Hindi and English. "
            "If the user speaks Hindi, reply in Hindi (using Devanagari script). "
            "If the user speaks English, reply in English. "
            "Keep your responses concise (under 2 sentences)."
        )
    )

    # --- 1. VAD TUNING (Fixes 'Fires off on background noise') ---
    # min_speech_duration: Ignore sounds shorter than 300ms (clicks/pops)
    # min_silence_duration: Wait 0.5s of silence before considering turn done
    # threshold: 0.6 (Higher = Less sensitive to background noise)
    vad_model = silero.VAD.load(
        min_speech_duration=0.3, 
        min_silence_duration=0.5, 
        activation_threshold=0.6 
    )

    # --- 2. EAR CONFIGURATION ---
    stt_config = deepgram.STT(
        model="nova-3-general",
        language="multi",    
        smart_format=True,
        # FIX: Parameter name is 'endpointing_ms', not 'endpointing'
        endpointing_ms=400, 
    )

    session = AgentSession(
        vad=vad_model,
        stt=stt_config,              
        llm=openai.LLM(                  
            base_url="https://api.groq.com/openai/v1",
            api_key=os.getenv("GROQ_API_KEY") or "",
            model="llama-3.1-8b-instant", 
        ),
        tts=MurfTTS(config=voice_state),                   
    )

    @ctx.room.local_participant.register_rpc_method("change_voice")
    async def change_voice(data: rtc.RpcInvocationData):
        new_voice_id = data.payload
        logger.info(f"Switching voice to: {new_voice_id}")
        voice_state["voice_id"] = new_voice_id
        return f"Voice changed to {new_voice_id}"

    await session.start(room=ctx.room, agent=participant_agent)
    await session.generate_reply(instructions="Say 'Namaste! I am Neo. I can speak Hindi and English.'")

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, agent_name="neo-nomad"))