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
from murf_tts import MurfTTS 

load_dotenv()
logger = logging.getLogger("voice-agent")

async def entrypoint(ctx: JobContext):
    # 1. Connect to the Room
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)

    # 2. Define the Persona (The "Agent")
    participant_agent = Agent(
        instructions=(
            "You are a helpful travel assistant for Northeast India. "
            "You are bilingual (Hindi and English). "
            "IMPORTANT: If the user speaks Hindi, reply in Hindi (Devanagari script). "
            "If the user speaks English, reply in English. "
            "Keep your responses concise (under 2 sentences)."
        )
    )


    # 2. THE EAR: Deepgram Auto-Detection
    # 'nova-2' is best for mixed languages. We enable 'smart_format' and 'detect_language'.
    stt_config = deepgram.STT(
        model="nova-3-general",
        smart_format=True,
        language="multi",
    )

    # 3. Define the Pipeline (The "Session")
    # This orchestrates STT -> LLM -> TTS
    session = AgentSession(
        vad=silero.VAD.load(),
        stt=stt_config, 
        llm=openai.LLM(
            base_url="https://api.groq.com/openai/v1",
            api_key=os.getenv("GROQ_API_KEY") or "",
            model="llama-3.1-8b-instant",
        ),
        tts=MurfTTS(), # We will update this file next
    )

    # 4. Bind Agent to Session and Start
    # This connects the persona to the room using the defined pipeline
    await session.start(room=ctx.room, agent=participant_agent)
    
    # 5. Initial Greeting
    await session.generate_reply(instructions="Say hello to the user")

if __name__ == "__main__":
    # "dev" for local testing
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))