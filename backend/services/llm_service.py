import os
from openai import OpenAI as OpenAIClient # Renamed to avoid conflict if OpenAI is used elsewhere
from pydantic import BaseModel, Field # Added Field
from typing import Literal, Dict, List, Optional # Added List, Optional
from fastapi import HTTPException
import pathlib # For path manipulation
import json # Added for JSON parsing

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

class POSMapping(BaseModel):
    word_target: str = Field(description = "A single word in the target language (e.g., Thai)")
    word_translit: str = Field(description = "The romanized/transliterated version of the target word")
    word_eng: str = Field(description="The English translation of the target word") # Corrected typo 'desecription' to 'description'
    pos: Literal['ADJ', 'ADP', 'ADV', 'AUX', 'CCONJ', 'DET','INTJ', 'NOUN',
                 'NUM', 'PART', 'PRON', 'PROPN', 'PUNCT', 'SCONJ', 'SYM', 'VERB', 'OTHER'] = Field(description="Part of speech tag for the target word")

class NPCResponse(BaseModel):
    input_target: str = Field(description="The latest input message from the user in the target language")
    input_english: str = Field(description="The latest input message from the user in English")
    input_mapping: List[POSMapping] = Field(description="The Part-of-Speech(POS) classification for each of words in the target latest input message")
    emotion: Literal["angry", "annoyed", "content", "happy", "sad", "surprised", "laughing"]
    response_tone: str
    response_target: str # This is the primary TargetLanguage response
    response_english: str # This is the English response
    response_mapping: List[POSMapping] = Field(description="POS tagging and word-level translations/transliterations in the response")
    charm_delta: int

async def get_llm_response(
    npc_id: str, 
    npc_name: str, 
    conversation_history: str, 
    latest_player_message: str,
    current_charm_level: int,
    target_language: str = "Thai"
) -> NPCResponse:
    """
    Gets a response from the OpenAI LLM based on the conversation history, latest player message, charm level, and system prompt for the NPC.
    
    Args:
        npc_id: The identifier for the NPC.
        npc_name: The name of the NPC.
        conversation_history: The conversation history up to (but not including) the latest player message.
        latest_player_message: The most recent message from the player.
        current_charm_level: The current charm level of the player with this NPC.
        target_language: The target language for the conversation (default: "Thai").
    
    Returns:
        NPCResponse object.
    """
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not initialized. Check API key.")

    system_prompt_for_npc = NPC_PROMPTS_CACHE.get(npc_id.lower())
    if not system_prompt_for_npc:
        system_prompt_for_npc = load_prompt_from_file(npc_id)
        if not system_prompt_for_npc:
            raise HTTPException(status_code=404, detail=f"NPC with ID '{npc_id}' not found or prompt file missing/unreadable.")
        NPC_PROMPTS_CACHE[npc_id.lower()] = system_prompt_for_npc

    # Format the input to match the desired structure
    llm_input = f"""Target Language: {target_language}
Current Charm: {current_charm_level}

Conversation History:
{conversation_history}

Respond to the latest message. If you don't understand what the user is saying, simply say you don't understand and ask the user to explain themselves.
Latest message:
Player: {latest_player_message}"""

    # print(f"""DEBUG: llm_input for {npc_id} (first 500 chars):
    # {llm_input[:500]}...""") # Commented out verbose log

    try:
        # Using client.responses.parse based on user's example
        response = openai_client.responses.parse(
            model="gpt-4.1-nano-2025-04-14", # Ensure this model is appropriate for .responses.parse
            instructions=system_prompt_for_npc,
            input=llm_input,
            text_format=NPCResponse, # This tells the client how to parse the text output from LLM into a Pydantic model
        )
        
        # The actual parsed Pydantic model is in response.output_parsed
        npc_response_data = response.output_parsed

        if not isinstance(npc_response_data, NPCResponse):
            # This case should ideally be caught by the text_format and parsing logic of the client
            print(f"LLM API call for {npc_id} did not return a parsed NPCResponse object as expected. Type: {type(npc_response_data)}")
            # Log the raw response if possible for debugging
            # raw_response_text = getattr(response, 'text', 'N/A') 
            # print(f"Raw response text: {raw_response_text[:500]}")
            raise HTTPException(status_code=500, detail="LLM service failed to parse response into the expected NPCResponse format.")

        if not npc_response_data.response_target:
             print(f"Warning: LLM for {npc_id} returned empty response_target.")
        
        if not npc_response_data.response_mapping:
            print(f"Warning: LLM for {npc_id} returned empty response_mapping. POS coloring will not work.")
            npc_response_data.response_mapping = []

        # print(f"DEBUG: NPC Response Data from LLM for {npc_id}: {npc_response_data.model_dump_json(indent=2)}") # Commented out very verbose log
        return npc_response_data
            
    except HTTPException: 
        raise
    except Exception as e:
        print(f"An unexpected error occurred in get_llm_response for {npc_id}: {e}")
        import traceback
        traceback.print_exc()
        # Attempt to get more info from the original response if it exists and might not be an HTTPException
        # error_details = str(e)
        # if hasattr(e, 'response') and hasattr(e.response, 'text'):
        #    error_details += f" - Response: {e.response.text[:200]}"
        raise HTTPException(status_code=500, detail=f"LLM service error: {str(e)}") 