import random
from livekit.agents import llm

@llm.function_tool(name="get_weather", description="Gets the current weather for a specific location in Northeast India")
async def get_weather(location: str) -> str:
    """Gets the current weather for a specific location in Northeast India.

    Args:
        location: The location or city to get the weather for (e.g. Guwahati, Shillong, Tawang).
    """
    conditions = ["sunny", "cloudy", "raining", "misty", "clear"]
    temperatures = {
        "guwahati": random.randint(25, 35),
        "shillong": random.randint(15, 25),
        "tawang": random.randint(5, 15),
        "gangtok": random.randint(10, 20),
        "kohima": random.randint(15, 25),
        "imphal": random.randint(20, 30),
        "aizawl": random.randint(20, 28),
        "agartala": random.randint(25, 35),
        "itanagar": random.randint(22, 32),
    }

    location_lower = location.lower()
    temp = None

    for city, typical_temp in temperatures.items():
        if city in location_lower:
            temp = typical_temp
            break

    if temp is None:
        # Default fallback for unknown locations in Northeast India
        temp = random.randint(15, 30)

    condition = random.choice(conditions)

    return f"The weather in {location} is currently {temp}°C and {condition}."
