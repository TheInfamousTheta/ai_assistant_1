import os
import logging
from datetime import timedelta
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from livekit import api
from dotenv import load_dotenv
from firebase_admin import auth, firestore
from firebase_config import get_firestore_db
from google.cloud import firestore as google_firestore

# Load environment variables
load_dotenv()

app = FastAPI()
logger = logging.getLogger("auth_server")
logging.basicConfig(level=logging.INFO)

# Configuration
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")
LIVEKIT_URL = os.getenv("LIVEKIT_URL")

# Initialize Firestore
db = get_firestore_db()

if not all([LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL]):
    raise ValueError("Missing required LiveKit environment variables")

class LoginRequest(BaseModel):
    id_token: str # Firebase Auth ID Token from Flutter

class TokenResponse(BaseModel):
    access_token: str
    url: str
    username: str
    room_name: str

@app.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """
    Exchanges a Firebase ID Token for a LiveKit Access Token.
    Saves user info to Firestore.
    """
    try:
        # 1. Verify Firebase Token
        # This checks signature, expiry, and project ID automatically
        decoded_token = auth.verify_id_token(request.id_token)
        uid = decoded_token['uid']
        email = decoded_token.get('email', '')
        name = decoded_token.get('name', 'Neo User')

        # 2. Sync User to Firestore (Upsert)
        # We store the user here so the Agent (main.py) can look up their name/preferences later
        user_ref = db.collection('users').document(uid)
        user_ref.set({
            'email': email,
            'display_name': name,
            'last_login': google_firestore.SERVER_TIMESTAMP
        }, merge=True)

        # 3. Generate Consistent Room Name based on UID
        room_name = f"neo-nomad-{uid}"

        # 4. Create LiveKit Token
        token = api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET) \
            .with_identity(uid) \
            .with_name(name) \
            .with_grants(api.VideoGrants(
                room_join=True,
                room=room_name, 
            )) \
            .with_ttl(timedelta(hours=6))

        jwt_token = token.to_jwt()

        # 5. Dispatch Agent
        # Note: In a production Firebase env, you might use Pub/Sub here 
        # to trigger the agent, but direct dispatch is fine for now.
        await dispatch_agent(room_name)

        return TokenResponse(
            access_token=jwt_token,
            url=LIVEKIT_URL or "",
            username=name,
            room_name=room_name
        )

    except Exception as e:
        logger.error(f"Login failed: {e}")
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

async def dispatch_agent(room_name: str):
    try:
        async with api.LiveKitAPI(LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET) as lkapi:
            await lkapi.agent_dispatch.create_dispatch(
                api.CreateAgentDispatchRequest(
                    room=room_name,
                    agent_name="neo-nomad", 
                    metadata="Firebase-Auth-Dispatched"
                )
            )
            logger.info(f"🚀 Agent dispatched to {room_name}")
    except Exception as e:
        logger.error(f"❌ Dispatch failed: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)