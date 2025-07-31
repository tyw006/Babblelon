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

def get_categories_by_npc_old(vocab_data: dict) -> List[str]:
    """Extract unique categories from vocabulary data (old version)."""
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
    
    categories = get_categories_by_npc_old(vocab_data)
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

# --- Quest State Management Functions (from test_LLM_v2.ipynb) ---

# Define Somchai's mandatory category order
SOMCHAI_CATEGORY_ORDER = [
    "Tableware/Utensils",
    "Drinks", 
    "Condiments",
    "Customer Actions/Requests",
    "Service Items"
]

def initialize_quest_state(npc_vocab_data: dict, npc_name: str = None) -> dict:
    """Initialize quest state with categories from vocabulary for dynamic quests"""
    categories = get_categories_by_npc(npc_vocab_data, npc_name)
    return {
        "categories_needed": categories,  # Static list of all categories for this NPC
        "conversation_turns": 0,
        "scenario_complete": False
    }

def process_item_giving(npc_response: 'NPCResponse', npc_config: dict) -> dict:
    """Process item after NPC judgment - updates external config state"""
    print(f"DEBUG: Processing item giving - Item: {npc_response.user_item_given}, Accepted: {npc_response.user_item_accepted}, Category: {npc_response.item_category}")
    
    if npc_response.user_item_given:
        # Add to items given history (external config)
        if "items_given" not in npc_config:
            npc_config["items_given"] = []
        npc_config["items_given"].append(npc_response.user_item_given)
        print(f"DEBUG: Added item '{npc_response.user_item_given}' to items_given. Total items given: {len(npc_config['items_given'])}")
        
        # If accepted, track the category (external config)
        if npc_response.user_item_accepted and npc_response.item_category:
            if "categories_accepted" not in npc_config:
                npc_config["categories_accepted"] = {}
            npc_config["categories_accepted"][npc_response.item_category] = npc_response.user_item_given
            print(f"DEBUG: Accepted item '{npc_response.user_item_given}' in category '{npc_response.item_category}'. Categories satisfied: {len(npc_config['categories_accepted'])}")
            
            # Check if quest complete (all categories satisfied)
            categories_needed = npc_config["quest_state"]["categories_needed"]
            if len(npc_config["categories_accepted"]) == len(categories_needed):
                npc_config["quest_state"]["scenario_complete"] = True
                print(f"DEBUG: Quest complete! All {len(categories_needed)} categories satisfied.")
            else:
                print(f"DEBUG: Quest not complete. {len(npc_config['categories_accepted'])}/{len(categories_needed)} categories satisfied.")
        else:
            print(f"DEBUG: Item '{npc_response.user_item_given}' was rejected or had no category.")
    else:
        print(f"DEBUG: No item given in this interaction.")
    
    return npc_config

def get_quest_summary(npc_config: dict) -> dict:
    """Get quest progress summary for dynamic quests with current/next category guidance"""
    # Get static categories needed
    categories_needed = npc_config["quest_state"]["categories_needed"]
    
    # Get dynamic state from external config
    categories_accepted = npc_config.get("categories_accepted", {})
    items_given = npc_config.get("items_given", [])
    
    categories_satisfied = list(categories_accepted.keys())
    categories_remaining = [c for c in categories_needed if c not in categories_accepted]
    
    # Calculate current and next category needed for focused guidance
    current_category_needed = categories_remaining[0] if len(categories_remaining) > 0 else "None (quest complete)"
    next_category_needed = categories_remaining[1] if len(categories_remaining) > 1 else "None (final category)" if len(categories_remaining) == 1 else "None (quest complete)"
    
    return {
        "progress": f"{len(categories_satisfied)}/{len(categories_needed)}",
        "categories_satisfied": categories_satisfied,
        "categories_remaining": categories_remaining,  # Keep for debugging
        "current_category_needed": current_category_needed,
        "next_category_needed": next_category_needed,
        "accepted_items": categories_accepted,
        "all_items_given": items_given,
        "complete": npc_config["quest_state"]["scenario_complete"]
    }

def format_conversation_history(conversation_history: str, max_turns: int = 2) -> str:
    """Format conversation history to last N turns"""
    if not conversation_history or not conversation_history.strip():
        return ""
    
    conversation_lines = conversation_history.strip().split('\n')
    max_lines = max_turns * 2  # Each turn has player + NPC line
    if len(conversation_lines) >= max_lines:
        return '\n'.join(conversation_lines[-max_lines:])
    return conversation_history

def get_categories_by_npc(vocab_data: dict, npc_name: str = None) -> List[str]:
    """Extract categories from vocabulary data, with ordering for Somchai and randomization for Amara"""
    if not vocab_data or 'vocabulary' not in vocab_data:
        return []
    
    categories = set()
    for item in vocab_data['vocabulary']:
        if 'category' in item:
            categories.add(item['category'])
    
    # Apply ordering for Somchai
    if npc_name == "Somchai":
        ordered_categories = []
        for cat in SOMCHAI_CATEGORY_ORDER:
            if cat in categories:
                ordered_categories.append(cat)
        # Add any remaining categories not in the predefined order
        for cat in categories:
            if cat not in ordered_categories:
                ordered_categories.append(cat)
        return ordered_categories
    
    # Apply randomization for Amara
    elif npc_name == "Amara":
        categories_list = list(categories)
        random.shuffle(categories_list)
        return categories_list
    
    # For other NPCs, return unordered list
    return list(categories)

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
    response_target: str = Field(description="The response in the target language")
    response_english: str = Field(description="The English response")
    response_mapping: List[POSMapping] = Field(description="POS tagging and word-level translations/transliterations in the response")
    user_item_given: Optional[str] = Field(description="Any item given by the user", default=None)
    user_item_accepted: bool = Field(description="Whether the NPC accepts this item for the current scenario")
    item_category: Optional[str] = Field(description="Category of the accepted item (e.g., 'Condiments', 'Proteins')")
    charm_delta: Literal[-10, -5, 0, 5, 10] = Field(description="The change in charm level")
    charm_reason: str = Field(description="The reason for the charm delta")

# Enhanced NPC Prompts with Dynamic Quest Systems - now loaded from files in backend/prompts/

def get_dynamic_prompt(npc_name: str) -> str:
    """Get the appropriate dynamic prompt for an NPC from file"""
    prompt = load_prompt_from_file(npc_name)
    if prompt is not None:
        return prompt
    else:
        # Fallback for unknown NPCs - try to load Amara
        print(f"Warning: No prompt file found for NPC '{npc_name}', trying Amara as fallback")
        fallback_prompt = load_prompt_from_file("amara")
        if fallback_prompt is not None:
            return fallback_prompt
        else:
            raise FileNotFoundError(f"Could not load prompt for NPC '{npc_name}' and fallback 'amara' prompt file not found")

# LLM Input Template for Dynamic Category-Based Quests
LLM_INPUT_TEMPLATE = """Charm score: {current_charm_level}
Items provided so far: {items_given}
Categories satisfied: {categories_satisfied}
Current category needed: {current_category_needed}
Next category needed: {next_category_needed}

Conversation history:
{conversation_history_last_2_turns}

# --- PLAYER INPUT THIS TURN ---------------------------------
Player message: {player_free_text}
Player action: {action_type}
Action item: {item_or_blank}
# ------------------------------------------------------------"""

async def get_llm_response(
    npc_id: str, 
    npc_name: str, 
    conversation_history: str, 
    latest_player_message: str,
    current_charm_level: int,
    target_language: str = "Thai",
    quest_state: Optional[Dict] = None,
    action_type: str = "",
    action_item: str = ""
) -> NPCResponse:
    """
    Dynamic quest-aware LLM response generation.
    Uses category tracking for quest completion with backend validation for item giving.
    
    Args:
        npc_id: The identifier for the NPC.
        npc_name: The name of the NPC.
        conversation_history: The conversation history.
        latest_player_message: The most recent message from the player.
        current_charm_level: The current charm level.
        target_language: The target language for the conversation.
        quest_state: Complete quest state with categories, progress, etc.
        action_type: "GIVE_ITEM" or "" (empty if sending message)
        action_item: Item being given (empty if sending message)
    
    Returns:
        NPCResponse object with quest fields.
    """
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not initialized. Check API key.")

    # Initialize or load NPC configuration with quest state
    npc_config = quest_state if quest_state else {}
    
    # Ensure quest state is properly initialized
    if not quest_state or "quest_state" not in quest_state:
        # Initialize quest state for new conversations
        vocab_data = load_vocabulary_data(npc_id)
        if vocab_data:
            npc_config = {
                "name": npc_name,
                "quest_state": initialize_quest_state(vocab_data, npc_name),
                "items_given": [],
                "categories_accepted": {}
            }
        else:
            # Fallback for missing vocabulary data
            print(f"WARNING: No vocabulary data found for NPC '{npc_id}', creating empty quest state")
            npc_config = {
                "name": npc_name,
                "quest_state": {"categories_needed": [], "scenario_complete": False},  # Changed to False - empty quest shouldn't be complete
                "items_given": [],
                "categories_accepted": {}
            }

    # Get dynamic prompts (will be implemented in next step)
    system_prompt = get_dynamic_prompt(npc_name)
    if not system_prompt:
        raise HTTPException(status_code=404, detail=f"NPC prompt not found for '{npc_name}'")

    # BACKEND ENFORCEMENT: Only process items with valid GIVE_ITEM action
    valid_item_action = (action_type == "GIVE_ITEM" and action_item.strip() != "")
    
    # Get quest progress for LLM context
    quest_summary = get_quest_summary(npc_config)
    
    # Debug logging for quest state
    print(f"DEBUG: Quest state for {npc_name}:")
    print(f"  Categories needed: {npc_config['quest_state']['categories_needed']}")
    print(f"  Categories satisfied: {quest_summary['categories_satisfied']}")
    print(f"  Current category needed: {quest_summary['current_category_needed']}")
    print(f"  Next category needed: {quest_summary['next_category_needed']}")
    print(f"  Quest complete: {quest_summary['complete']}")
    print(f"  Items given: {npc_config.get('items_given', [])}")
    print(f"  Categories accepted: {npc_config.get('categories_accepted', {})}")
    
    # Format conversation history
    conversation_history_last_2_turns = format_conversation_history(conversation_history, 2)
    
    # LLM input for dynamic quests - now includes current and next category guidance
    llm_input = LLM_INPUT_TEMPLATE.format(
        current_charm_level=current_charm_level,
        items_given=npc_config.get("items_given", []),
        categories_satisfied=quest_summary["categories_satisfied"],
        current_category_needed=quest_summary["current_category_needed"],
        next_category_needed=quest_summary["next_category_needed"],
        conversation_history_last_2_turns=conversation_history_last_2_turns,
        player_free_text=latest_player_message,
        action_type=action_type if action_type else "NONE",
        item_or_blank=action_item if valid_item_action else ""
    )
    
    print(f"🤖 Calling LLM for {npc_name}...")
    print(f"📝 LLM Input: {llm_input}")
    
    try:
        # Call OpenAI using correct responses.parse structure
        response = openai_client.responses.parse(
            model="gpt-4.1-mini-2025-04-14",
            instructions=system_prompt,
            input=llm_input,
            text_format=NPCResponse,
        )
        
        # BACKEND ENFORCEMENT: Override LLM's user_item_given based on action validation
        npc_response = response.output_parsed
        if not valid_item_action:
            npc_response.user_item_given = None  # Force to None if no valid action
        else:
            npc_response.user_item_given = action_item  # Ensure it matches what was actually given
        
        if not npc_response.response_target:
            print(f"Warning: LLM for {npc_id} returned empty response_target.")
        
        if not npc_response.response_mapping:
            print(f"Warning: LLM for {npc_id} returned empty response_mapping. POS coloring will not work.")
            npc_response.response_mapping = []

        return npc_response
        
    except Exception as e:
        print(f"An unexpected error occurred in get_llm_response for {npc_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"LLM service error: {str(e)}") 