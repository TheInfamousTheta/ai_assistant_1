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

async def create_token(room, identity, hours):
    """Generates a JWT token for the Frontend"""
    print(f"🔑 Generating token for '{identity}' in room '{room}'...")
    
    token = api.AccessToken(API_KEY, API_SECRET) \
        .with_identity(identity) \
        .with_name(identity) \
        .with_grants(api.VideoGrants(
            room_join=True,
            room=room,
        )) \
        .with_ttl(hours * 3600) # Convert hours to seconds
    
    jwt = token.to_jwt()
    print("\n" + "="*60)
    print(f"TOKEN (Valid for {hours} hours):")
    print("-" * 60)
    print(jwt)
    print("="*60 + "\n")
    print("👉 Paste this into your Flutter .env file as LIVEKIT_TOKEN")

async def delete_room(room):
    """Kicks everyone out and deletes the room"""
    print(f"🗑️  Purging room '{room}'...")
    
    async with api.LiveKitAPI(LIVEKIT_URL, API_KEY, API_SECRET) as lkapi:
        try:
            # DeleteRoomRequest requires the room name
            await lkapi.room.delete_room(api.DeleteRoomRequest(room=room))
            print(f"✅ Room '{room}' successfully deleted.")
            print("All participants (Agent + Flutter) have been disconnected.")
        except Exception as e:
            print(f"❌ Failed to delete room (it might be empty already): {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LiveKit Hackathon Tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Command: python manage.py dispatch
    dispatch_parser = subparsers.add_parser("dispatch", help="Force agent to join the room")
    dispatch_parser.add_argument("--room", default="techfest-demo", help="Room name")
    dispatch_parser.add_argument("--agent-name", default="neo-nomad", help="Agent name defined in main.py")

    # Command: python manage.py token
    token_parser = subparsers.add_parser("token", help="Generate a frontend token")
    token_parser.add_argument("--room", default="techfest-demo", help="Room name")
    token_parser.add_argument("--identity", default="flutter-user", help="User identity")
    token_parser.add_argument("--hours", type=int, default=168, help="Validity in hours (168 = 1 week)")

    # Command: python manage.py delete
    delete_parser = subparsers.add_parser("delete", help="Delete room and kick everyone out")
    delete_parser.add_argument("--room", default="techfest-demo", help="Room name")

    args = parser.parse_args()

    if args.command == "dispatch":
        asyncio.run(create_dispatch(args.room, args.agent_name))
    elif args.command == "token":
        asyncio.run(create_token(args.room, args.identity, args.hours))
    elif args.command == "delete":
        asyncio.run(delete_room(args.room))