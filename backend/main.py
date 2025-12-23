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
from firebase_config import get_firestore_db
from typing import Any

load_dotenv()
logger = logging.getLogger("voice-agent")

# Initialize Firestore
db = get_firestore_db()

async def entrypoint(ctx: JobContext):
    logger.info(f"Connecting to room {ctx.room.name}")
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)

    # 1. Identify User from Room Name
    # Room format is "neo-nomad-{uid}"
    try:
        user_uid = ctx.room.name.replace("neo-nomad-", "")
        user_ref = db.collection('users').document(user_uid)
        user_doc: Any = await asyncio.to_thread(user_ref.get)        
        # Load persisted voice preference, default to Zion if not set
        if user_doc.exists:
            user_data = user_doc.to_dict()
            stored_voice = user_data.get('preferred_voice', "en-US-zion")
            user_name = user_data.get('display_name', "Traveler")
        else:
            stored_voice = "en-US-zion"
            user_name = "Traveler"
            
    except Exception as e:
        logger.error(f"Error fetching user data from Firestore: {e}")
        stored_voice = "en-US-zion"
        user_name = "Traveler"

    # Shared State
    voice_state = {"voice_id": stored_voice}
    logger.info(f"Loaded voice preference for {user_name}: {stored_voice}")

    participant_agent = Agent(
        instructions=(
            f"You are 'Neo', a smart travel companion for Northeast India created by Team Neo Nomads. "
            f"You are speaking to {user_name}. "
            "You are fully bilingual in Hindi and English. "
            "If the user speaks Hindi, reply in Hindi (using Devanagari script). "
            "If the user speaks English, reply in English. "
        )
    )

    vad_model = silero.VAD.load(
        min_speech_duration=0.3, 
        min_silence_duration=0.5, 
        activation_threshold=0.6 
    )

    stt_config = deepgram.STT(
        model="nova-3-general",
        language="multi",    
        smart_format=True,
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
        
        # Update local state
        voice_state["voice_id"] = new_voice_id
        
        # PERSIST STATE: Update Firestore so we remember this next time
        try:
            if user_uid:
                db.collection('users').document(user_uid).update({
                    'preferred_voice': new_voice_id
                })
                logger.info("✅ Persisted voice choice to Firestore")
        except Exception as e:
            logger.error(f"Failed to persist voice choice: {e}")

        return f"Voice changed to {new_voice_id}"

    await session.start(room=ctx.room, agent=participant_agent)
    await session.generate_reply(instructions=f"Say 'Namaste {user_name}! I am Neo. I can speak Hindi and English.'")

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, agent_name="neo-nomad"))