import os
from openai import OpenAI as OpenAIClient # Renamed to avoid conflict if OpenAI is used elsewhere
from pydantic import BaseModel, Field # Added Field
from typing import Literal, Dict, List, Optional # Added List, Optional
from fastapi import HTTPException
import pathlib # For path manipulation
import json # Added for JSON parsing
import random # Added for vocabulary selection

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

# --- Helper functions for vocabulary selection ---
def load_vocabulary_data(npc_id: str) -> dict | None:
    """Load vocabulary data for a specific NPC from JSON file."""
    current_dir = pathlib.Path(__file__).parent # backend/services
    assets_dir = current_dir.parent.parent / "assets" / "data" # ../../assets/data
    vocab_file = assets_dir / f"npc_vocabulary_{npc_id.lower()}.json"
    
    if not vocab_file.exists():
        print(f"Warning: Vocabulary file not found for NPC '{npc_id}' at {vocab_file}")
        return None
    
    try:
        with open(vocab_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading vocabulary for NPC '{npc_id}' from {vocab_file}: {e}")
        return None

def get_categories_by_npc(vocab_data: dict) -> List[str]:
    """Extract unique categories from vocabulary data."""
    if not vocab_data or 'vocabulary' not in vocab_data:
        return []
    
    categories = set()
    for item in vocab_data['vocabulary']:
        if 'category' in item:
            categories.add(item['category'])
    return list(categories)

def select_random_vocabulary_from_category(vocab_data: dict, category: str, count: int = 1) -> List[dict]:
    """Select random vocabulary items from a specific category."""
    if not vocab_data or 'vocabulary' not in vocab_data:
        return []
    
    category_items = [
        item for item in vocab_data['vocabulary'] 
        if item.get('category') == category
    ]
    
    if not category_items:
        return []
    
    # Return random selection (up to count items)
    return random.sample(category_items, min(count, len(category_items)))

def initialize_npc_vocabulary(npc_id: str) -> dict:
    """Initialize NPC with random vocabulary from each category."""
    vocab_data = load_vocabulary_data(npc_id)
    if not vocab_data:
        print(f"Warning: Could not load vocabulary data for NPC '{npc_id}'")
        return {}
    
    categories = get_categories_by_npc(vocab_data)
    selected_vocab = {}
    
    print(f"🎲 Initializing {npc_id} with random vocabulary from {len(categories)} categories:")
    
    for category in categories:
        # Select 1 random item from each category
        selected_items = select_random_vocabulary_from_category(vocab_data, category, 1)
        if selected_items:
            selected_vocab[category] = selected_items[0]
            item = selected_items[0]
            print(f"  🎯 {category}: {item['english']} ({item['thai']}) - {item['transliteration']}")
    
    return selected_vocab

def regenerate_npc_vocabulary(npc_id: str) -> dict:
    """Regenerate vocabulary for an NPC and clear the cache."""
    # Clear the cache for this NPC
    if npc_id.lower() in NPC_VOCABULARY_CACHE:
        del NPC_VOCABULARY_CACHE[npc_id.lower()]
    
    # Generate new vocabulary
    return initialize_npc_vocabulary(npc_id)

def format_vocabulary_context(selected_vocab: dict) -> str:
    """Format selected vocabulary for inclusion in the LLM prompt."""
    if not selected_vocab:
        return ""
    
    vocab_context = "\n\n## CURRENT SESSION VOCABULARY\n"
    vocab_context += "You have access to these vocabulary items for this conversation:\n"
    for category, item in selected_vocab.items():
        vocab_context += f"- **{category}**: {item['english']} = {item['thai']} ({item['transliteration']})\n"
    vocab_context += "\nFeel free to naturally incorporate these terms when appropriate.\n"
    
    return vocab_context

# --- Load prompts dynamically ---
# We'll load them on demand in the get_llm_response function or cache them if preferred.
# For simplicity now, we load them when requested.

NPC_PROMPTS_CACHE: Dict[str, str] = {} # Optional: For caching loaded prompts
NPC_VOCABULARY_CACHE: Dict[str, dict] = {} # Cache for NPC vocabulary selections

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
    charm_reason: str = Field(description="The reason for the charm delta")

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

    # Load base system prompt
    system_prompt_for_npc = NPC_PROMPTS_CACHE.get(npc_id.lower())
    if not system_prompt_for_npc:
        system_prompt_for_npc = load_prompt_from_file(npc_id)
        if not system_prompt_for_npc:
            raise HTTPException(status_code=404, detail=f"NPC with ID '{npc_id}' not found or prompt file missing/unreadable.")
        NPC_PROMPTS_CACHE[npc_id.lower()] = system_prompt_for_npc

    # Initialize vocabulary for this NPC session (or use cached)
    selected_vocab = NPC_VOCABULARY_CACHE.get(npc_id.lower())
    if not selected_vocab:
        selected_vocab = initialize_npc_vocabulary(npc_id)
        if selected_vocab:
            NPC_VOCABULARY_CACHE[npc_id.lower()] = selected_vocab

    # Enhance system prompt with vocabulary context
    enhanced_prompt = system_prompt_for_npc
    if selected_vocab:
        vocab_context = format_vocabulary_context(selected_vocab)
        enhanced_prompt += vocab_context

    # Format the input to match the desired structure
    llm_input = f"""Target Language: {target_language}
Current Charm: {current_charm_level}

Conversation History:
{conversation_history}

Respond to the latest message:
Player: {latest_player_message}"""

    try:
        # Using client.responses.parse based on user's example
        response = openai_client.responses.parse(
            model="gpt-4.1-nano-2025-04-14", # Ensure this model is appropriate for .responses.parse
            instructions=enhanced_prompt,
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