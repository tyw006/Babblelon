import os
from openai import OpenAI as OpenAIClient # Renamed to avoid conflict if OpenAI is used elsewhere
from pydantic import BaseModel
from typing import Literal, Dict
from fastapi import HTTPException
import pathlib # For path manipulation

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    print("Warning: OPENAI_API_KEY not found in environment variables.")

openai_client = None
if OPENAI_API_KEY:
    try:
        openai_client = OpenAIClient(api_key=OPENAI_API_KEY)
    except Exception as e:
        print(f"Error initializing OpenAI client: {e}")

# --- Helper function to load prompts ---
def load_prompt_from_file(npc_id: str) -> str | None:
    """Loads a prompt for a given NPC ID from a .txt file in the prompts directory."""
    # Construct the path to the prompt file
    # Assuming this service file is in backend/services/ and prompts are in backend/prompts/
    current_dir = pathlib.Path(__file__).parent # backend/services
    prompts_dir = current_dir.parent / "prompts" # backend/prompts
    prompt_file = prompts_dir / f"{npc_id.lower()}_prompt.txt"
    
    if not prompt_file.exists():
        print(f"Warning: Prompt file not found for NPC '{npc_id}' at {prompt_file}")
        return None
    try:
        with open(prompt_file, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        print(f"Error loading prompt for NPC '{npc_id}' from {prompt_file}: {e}")
        return None

# --- Load prompts dynamically ---
# We'll load them on demand in the get_llm_response function or cache them if preferred.
# For simplicity now, we load them when requested.

NPC_PROMPTS_CACHE: Dict[str, str] = {} # Optional: For caching loaded prompts

# --- End Prompt Definitions ---

class NPCResponse(BaseModel):
    expression: Literal["angry", "annoyed", "content", "happy", "sad", "surprised", "laughing"]
    response_tone: str
    response_thai: str
    response_eng: str
    response_rtgs: str
    charm_delta: int
    # Potentially, the LLM could also be asked to return the new absolute charm level
    # new_charm_level: int | None = None 

async def get_llm_response(user_message_with_history: str, npc_id: str, charm_level: int) -> NPCResponse | None:
    """
    Gets a response from the OpenAI LLM based on the user message, conversation history, charm level, and system prompt.
    user_message_with_history: The user's latest utterance, potentially prefixed with conversation history.
    npc_id: The identifier for the NPC.
    charm_level: The current charm level of the player with this NPC.
    Returns an NPCResponse object or None if an error occurs.
    """
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not initialized. Check API key.")

    # Load prompt (with optional caching)
    system_prompt_for_npc = NPC_PROMPTS_CACHE.get(npc_id.lower())
    if not system_prompt_for_npc:
        system_prompt_for_npc = load_prompt_from_file(npc_id)
        if not system_prompt_for_npc:
            raise HTTPException(status_code=404, detail=f"NPC with ID '{npc_id}' not found or prompt file missing/unreadable.")
        NPC_PROMPTS_CACHE[npc_id.lower()] = system_prompt_for_npc # Cache it

    # Incorporate charm level into the input for the LLM
    # The system_prompt_for_npc should instruct the LLM how to interpret this.
    llm_input_with_charm = f"""Observe the conversation history and respond to the latest message.
    Current Charm with {npc_id.capitalize()}: {charm_level}
    Conversation History:{user_message_with_history}"""

    try:
        response = openai_client.responses.parse(
            model="gpt-4.1-nano-2025-04-14", 
            instructions=system_prompt_for_npc, 
            input=llm_input_with_charm, # Use the input with charm level
            text_format=NPCResponse, 
        )
        
        if response and response.output_parsed:
            return response.output_parsed
        else:
            print("OpenAI LLM did not return a valid parsed response.")
            # Consider if more specific error handling is needed here
            raise HTTPException(status_code=500, detail="LLM did not return a valid parsed response.")
            
    except Exception as e:
        print(f"Error during OpenAI LLM call: {e}")
        # Consider if you want to expose parts of the error to the client
        raise HTTPException(status_code=500, detail=f"Error processing message with LLM: {str(e)}") 