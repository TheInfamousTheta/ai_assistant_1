import os
import asyncio
import argparse
from dotenv import load_dotenv
from livekit import api

# Load keys from .env
load_dotenv()
LIVEKIT_URL = os.getenv("LIVEKIT_URL")
API_KEY = os.getenv("LIVEKIT_API_KEY")
API_SECRET = os.getenv("LIVEKIT_API_SECRET")

if not all([LIVEKIT_URL, API_KEY, API_SECRET]):
    print("Error: Missing LiveKit credentials in .env file.")
    exit(1)

async def create_dispatch(room, agent_name):
    """Forces the backend agent to join a specific room"""
    print(f"🚀 Dispatching agent '{agent_name}' to room '{room}'...")
    
    async with api.LiveKitAPI(LIVEKIT_URL, API_KEY, API_SECRET) as lkapi:
        try:
            dispatch = await lkapi.agent_dispatch.create_dispatch(
                api.CreateAgentDispatchRequest(
                    room=room,
                    agent_name=agent_name,
                )
            )
            print(f"✅ Success! Dispatch ID: {dispatch.id}")
            print("Check your Agent terminal - it should be joining now.")
        except Exception as e:
            print(f"❌ Failed to dispatch: {e}")

async def list_rooms():
    """Lists all active rooms (useful to find user rooms)"""
    print("🔍 Scanning for active rooms...")
    async with api.LiveKitAPI(LIVEKIT_URL, API_KEY, API_SECRET) as lkapi:
        results = await lkapi.room.list_rooms(api.ListRoomsRequest())
        if not results.rooms:
            print("No active rooms found.")
        for room in results.rooms:
            print(f" - {room.name} (Participants: {room.num_participants})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LiveKit Admin Tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Command: python manage.py dispatch --room "neo-nomad-user@gmail.com"
    dispatch_parser = subparsers.add_parser("dispatch", help="Force agent to join the room")
    dispatch_parser.add_argument("--room", required=True, help="Room name (e.g., neo-nomad-user@email.com)")
    dispatch_parser.add_argument("--agent-name", default="neo-nomad", help="Agent name defined in main.py")

    # Command: python manage.py list
    list_parser = subparsers.add_parser("list", help="List active rooms")

    args = parser.parse_args()

    if args.command == "dispatch":
        asyncio.run(create_dispatch(args.room, args.agent_name))
    elif args.command == "list":
        asyncio.run(list_rooms())