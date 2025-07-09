# Development Partnership

We're building production-quality code together. Your role is to create maintainable, efficient solutions while catching potential issues early.

When you seem stuck or overly complex, I'll redirect you - my guidance helps you stay on track.

## 🚨 AUTOMATED CHECKS ARE MANDATORY
**ALL build/analyze issues are BLOCKING - EVERYTHING must be ✅ GREEN!**  
No errors. No formatting issues. No linting problems. Zero tolerance.  
These are not suggestions. Fix ALL issues before continuing.

## CRITICAL WORKFLOW - ALWAYS FOLLOW THIS!

### Research → Plan → Implement
**NEVER JUMP STRAIGHT TO CODING!** Always follow this sequence:
1. **Research**: Explore the codebase, understand existing patterns
2. **Plan**: Create a detailed implementation plan and verify it with me  
3. **Implement**: Execute the plan with validation checkpoints

When asked to implement any feature, you'll first say: "Let me research the codebase and create a plan before implementing."

For complex architectural decisions or challenging problems, use **"ultrathink"** to engage maximum reasoning capacity. Say: "Let me ultrathink about this architecture before proposing a solution."

### USE MULTIPLE AGENTS!
*Leverage subagents aggressively* for better results:

* Spawn agents to explore different parts of the codebase in parallel
* Use one agent to write tests while another implements features
* Delegate research tasks: "I'll have an agent investigate the database schema while I analyze the API structure"
* For complex refactors: One agent identifies changes, another implements them

Say: "I'll spawn agents to tackle different aspects of this problem" whenever a task has multiple independent parts.

### Reality Checkpoints
**Stop and validate** at these moments:
- After implementing a complete feature
- Before starting a new major component  
- When something feels wrong
- Before declaring "done"
- **WHEN BUILD/ANALYZE FAILS WITH ERRORS** ❌

Run: `flutter analyze && flutter build`

> Why: You can lose track of what's actually working. These checkpoints prevent cascading failures.

### 🚨 CRITICAL: Build/Analyze Failures Are BLOCKING
**When flutter analyze or flutter build report ANY issues, you MUST:**
1. **STOP IMMEDIATELY** - Do not continue with other tasks
2. **FIX ALL ISSUES** - Address every ❌ issue until everything is ✅ GREEN
3. **VERIFY THE FIX** - Re-run the failed command to confirm it's fixed
4. **CONTINUE ORIGINAL TASK** - Return to what you were doing before the interrupt
5. **NEVER IGNORE** - There are NO warnings, only requirements

This includes:
- Build errors (compilation failures, missing dependencies)
- Linting violations (formatting, unused imports, etc.)
- Analysis issues (type errors, deprecated APIs)
- ALL other checks

Your code must be 100% clean. No exceptions.

**Recovery Protocol:**
- When interrupted by a build/analyze failure, maintain awareness of your original task
- After fixing all issues and verifying the fix, continue where you left off
- Use the todo list to track both the fix and your original task

## Project Overview

BabbleOn is a voice-driven Thai language learning mobile game built with Flutter and Flame engine. Players explore Bangkok's Yaowarat (Chinatown) district at night, practicing Thai through conversations with AI-powered NPCs. The game combines 2D side-scrolling gameplay with speech recognition, AI-generated dialogue, and text-to-speech technology.

## Technology Stack

- **Frontend**: Flutter 3.2.0+ with Flame game engine, Riverpod state management, Isar local database
- **Backend**: FastAPI (Python) with multiple AI service integrations
- **AI Services**: OpenAI GPT-4o/Google Gemini (LLM), Azure Speech (STT), ElevenLabs/Google TTS, Google Translate
- **Database**: Supabase (PostgreSQL with pgvector for embeddings)

## Essential Development Commands

### Flutter/Mobile App
```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# 🚨 MANDATORY: Build and analyze after ANY code changes
flutter analyze
flutter build

# Generate code (for Riverpod providers and Isar models)
dart run build_runner build
```

**IMPORTANT**: Never use `flutter run` - only use `flutter build` and `flutter analyze` for verification.

### Backend API
```bash
# Run FastAPI server (from backend/ directory)
uv run main.py

# Test individual AI services
uv run test_files/test_openai_llm.py
uv run test_files/test_elevenlabs_stt.py
uv run test_pronunciation_api.py

# Run any Python files or tests in backend
uv run <filename.py>
```

**Note**: This project uses `uv` for Python environment management. Always use `uv run` to execute Python files in the backend directory.

### Environment Setup
- Create `.env` file in root with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Backend API keys configured in FastAPI service classes

## Working Memory Management

### When context gets long:
- Re-read this CLAUDE.md file
- Summarize progress in a PROGRESS.md file
- Document current state before major changes

### Maintain TODO.md:
```
## Current Task
- [ ] What we're doing RIGHT NOW

## Completed  
- [x] What's actually done and tested

## Next Steps
- [ ] What comes next
```

## Flutter/Python-Specific Rules

### FORBIDDEN - NEVER DO THESE:
- **NO** magic numbers - use named constants
- **NO** keeping old and new code together
- **NO** migration functions or compatibility layers
- **NO** versioned function names (processV2, handleNew)
- **NO** TODOs in final code
- **NO** skipping flutter build validation

### Required Standards:
- **Delete** old code when replacing it
- **Meaningful names**: `userId` not `id`
- **Early returns** to reduce nesting
- **Proper error handling** with try-catch blocks
- **Type safety**: Always declare types, avoid `dynamic`
- **Code generation**: Run `dart run build_runner build` after provider changes
- **Python uv usage**: Always use `uv run` for backend Python execution

## Implementation Standards

### Our code is complete when:
- ✅ `flutter analyze` passes with zero issues
- ✅ `flutter build` succeeds without errors
- ✅ All tests pass  
- ✅ Feature works end-to-end
- ✅ Old code is deleted
- ✅ Code follows project patterns

### Testing Strategy
- Widget tests for UI components (`flutter test`)
- Integration tests for AI service modules
- Backend API testing via `uv run test_files/`

## Problem-Solving Together

When you're stuck or confused:
1. **Stop** - Don't spiral into complex solutions
2. **Delegate** - Consider spawning agents for parallel investigation
3. **Ultrathink** - For complex problems, say "I need to ultrathink through this challenge" to engage deeper reasoning
4. **Step back** - Re-read the requirements
5. **Simplify** - The simple solution is usually correct
6. **Ask** - "I see two approaches: [A] vs [B]. Which do you prefer?"

My insights on better approaches are valued - please ask for them!

## Performance & Security

### **Measure First**:
- No premature optimization
- Use Flutter DevTools for real bottlenecks
- Profile before claiming something is faster

### **Security Always**:
- Validate all inputs
- Never commit secrets to repository
- Use environment variables for sensitive data
- Sanitize user inputs before processing

## Communication Protocol

### Progress Updates:
```
✓ Implemented character tracing widget (all tests passing)
✓ Added pronunciation assessment  
✗ Found issue with audio playback - investigating
```

### Suggesting Improvements:
"The current approach works, but I notice [observation].
Would you like me to [specific improvement]?"

## Working Together

- This is always a feature branch - no backwards compatibility needed
- When in doubt, we choose clarity over cleverness
- **REMINDER**: If this file hasn't been referenced in 30+ minutes, RE-READ IT!

Avoid complex abstractions or "clever" code. The simple, obvious solution is probably better, and my guidance helps you stay focused on what matters.

## Architecture Overview

### Core Game Loop
```
Player Speech → STT (Azure) → LLM Processing (GPT-4o/Gemini) → TTS (ElevenLabs) → NPC Response
```

### Key Directories
- `lib/game/`: Flame engine components (player, NPCs, collision detection, camera)
- `lib/screens/`: Flutter UI screens (menu, game interface, boss fights)
- `lib/providers/`: Riverpod state management for game state, user data, AI services
- `lib/services/`: API integrations and external service wrappers
- `backend/services/`: Python AI service implementations
- `assets/data/`: Game vocabulary, NPC dialogue data, quest definitions

### State Management Pattern
- Uses Riverpod with code generation (`@riverpod` annotations)
- Game state managed through providers in `lib/providers/`
- Local persistence via Isar database for offline functionality
- Supabase integration for user data and premium features

### Game Architecture
- `BabbleLonGame` class extends FlameGame with collision detection
- Component-based entities (Player, NPCs, Portals, Speech bubbles)
- Quest system with vocabulary tracking and spaced repetition
- NPC charm system with facial expressions based on conversation quality

## Development Guidelines

### Code Style
- **Naming Conventions**: PascalCase for classes, camelCase for variables/functions, underscores_case for file/directory names
- **Type Safety**: Always declare types, avoid `dynamic`, create necessary types when needed
- **Function Design**: Write short functions (<20 instructions) with single purpose, start function names with verbs
- **Boolean Variables**: Use verbs for boolean variables (isLoading, hasError, canDelete)
- **Constants**: Use UPPERCASE for environment variables, avoid magic numbers

### Flutter-Specific Best Practices
- **Architecture**: Use clean architecture with repository pattern, controller pattern with Riverpod
- **State Management**: Use Riverpod with `@riverpod` annotations and code generation
- **Widget Design**: 
  - Break down complex widgets to avoid deep nesting
  - Use `const` constructors wherever possible to reduce rebuilds
  - Create reusable components for better code organization
- **Data Management**: 
  - Repository pattern for data persistence (Isar local, Supabase cloud)
  - Use immutable data structures where possible
  - Avoid data validation in functions, use classes with internal validation

### Code Organization
- **File Structure**: One export per file, use extensions for reusable code
- **Functions**: Use higher-order functions (map, filter, reduce) to avoid nesting
- **Error Handling**: Use exceptions for unexpected errors, add context when catching
- **Dependencies**: Use getIt for dependency injection (singleton for services/repositories)

### Project-Specific Requirements
- **Environment Setup**: Always verify `.env` file exists with required Supabase credentials
- **Code Generation**: Run `dart run build_runner build` after changes to Riverpod providers or Isar models  
- **Verification**: Always run `flutter analyze` and `flutter build` before committing
- **Scan Before Creating**: Check existing files before creating new ones to avoid duplication

## AI Service Integration

### Backend Services (`backend/services/`)
- `llm_service.py`: GPT-4o and Gemini integration for NPC dialogue
- `stt_service.py`: Azure Speech-to-Text for player input
- `tts_service.py`: ElevenLabs and Google TTS for NPC responses
- `pronunciation_service.py`: Azure pronunciation assessment
- `translation_service.py`: Google Translate with Thai romanization

### Frontend Integration (`lib/services/`)
- HTTP API calls to FastAPI backend
- Audio recording and playback via flutter_sound/audioplayers
- Real-time speech processing pipeline

## Extension Over Creation Rules
- **CRITICAL RULE**: Always extend existing services/files instead of creating new separate files
- **BACKEND SCANNING REQUIREMENT**: Before implementing new logic, scan the `backend/` directory to identify existing functions and services that can be extended
- **Pattern**: Look for existing functions that can be enhanced with new parameters
- **Implementation Process**:
  1. Scan backend directory for existing related functionality
  2. Check services like `translation_service.py`, `llm_service.py`, etc.
  3. Identify existing endpoints in `main.py`
  4. Extend existing functions rather than creating new ones
- **Verification**: Check existing codebase thoroughly before creating any new files

