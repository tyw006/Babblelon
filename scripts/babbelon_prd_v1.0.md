# Overview
Babbelon is a global, voice-only **2D side-scrolling adventure game** designed to teach travelers the local language of various cities. The Minimum Viable Product (MVP) focuses on the first chapter: **a visually stunning, 16-bit depiction of Yaowarat (Bangkok's Chinatown) at Night**, catering to English speakers learning Thai. Players will navigate this single, detailed map area, similar in style to a MapleStory map. The core gameplay is developed using Flutter with the Flame engine, while FlutterFlow is utilized for no-code UI screens such as onboarding, settings, spaced-repetition drills, and the paywall.

The vision is to create an immersive and engaging language learning experience by simulating real-world Thai conversations—ordering street food, haggling at a market, chatting with a taxi driver—all within this fun, retro-style game context. The game culminates in exciting boss fights where players must use their pronunciation skills to win. By leveraging AI for speech recognition and dynamic dialogue generation, Babbelon aims to provide practice beyond static, scripted phrases, making language learning more effective and enjoyable. Future downloadable quests will expand to entirely new cities like Tokyo and Paris, offering new languages, cultures, and distinct map areas.

The art direction for the MVP involves prototyping both retro pixel art and vibrant hand-drawn 2D art in the initial week of development, with a final style to be locked in after review, ensuring the **Yaowarat at Night setting is visually stunning with all its lights and atmosphere.**

# Core Features

**1. Voice-Driven 2D Side-Scrolling Adventure Gameplay:**
    - **What it does:** Players navigate a **single, detailed 2D side-scrolling map of Yaowarat at Night**, interacting with AI-driven Non-Player Characters (NPCs) using their voice to practice and learn Thai.
    - **Why it's important:** Offers an immersive, hands-free method of language practice, focusing on speaking and listening comprehension in realistic scenarios, which is more engaging than traditional methods.
    - **How it works:** Players speak Thai phrases into their device's microphone. The game uses a sophisticated AI pipeline (STT → optional Translation → LLM → optional Translation → TTS) to process the player's speech, generate an appropriate NPC response, and voice it back to the player. Dialogue is also displayed in Thai script with optional transliteration and English subtitles.

**2. Yaowarat Starter Quest: "Top 3 Yaowarat Bites"**
    - **What it does:** The initial questline where players help a Thai food blogger find three iconic dishes, **all within the Yaowarat at Night map.**
    - **Why it's important:** Provides a clear, goal-oriented introduction to the game's mechanics and core vocabulary set in an authentic, culturally rich environment.
    - **How it works:** Players interact with three specific food vendors (Guay Jub Ouan Pochana, Khao Phad Pu Chang Phueak, Pa Tong Go Savoey), using a beginner set of Thai keywords/phrases to "charm" each vendor and collect their signature dish. Success (≥2 correct phrases used) unlocks progress.
    - **Charm/Friendship Score:** Successfully navigating conversations increases a "charm" score with NPCs, potentially unlocking new dialogue or information. **NPC facial expressions will change based on the charm score:**
        -   **0-25% charm:** Angry face
        -   **25-50% charm:** Skeptical/annoyed face
        -   **50-75% charm:** Neutral pleasant face
        -   **75-100% charm:** Beaming smiling face
        -   **Note:** Not every message will affect the charm score. Only messages that are interpreted by the AI as genuinely attempting to build rapport, offer compliments, or show kindness will increase charm. Conversely, messages perceived as mean, annoying, or significantly off-topic (after a gentle redirect) may decrease charm. Transactional messages usually won't change the charm score.
    - **Quest Progression:** Completing conversational objectives within quests advances the storyline and unlocks new areas or content **within the Yaowarat map or future city maps.**

**3. "Practice-Anytime" Chat (Premium Feature):**
    - **What it does:** Allows premium subscribers to engage in unlimited, open-ended conversations with any NPC they've unlocked in the game.
    - **Why it's important:** Offers extended practice opportunities beyond scripted quests, catering to learners who want more free-form conversational practice.
    - **How it works:** Utilizes the same AI conversation pipeline but incorporates long-term memory for NPCs (stored in Supabase with pgvector) to recall previous interactions, making conversations more personalized and coherent over time. Free users get a limited number of practice messages per NPC daily.

**4. AI Speech Conversation Pipeline:**
    - **What it does:** The technical backbone enabling dynamic voice conversations.
    - **Why it's important:** Allows for natural, unscripted interactions, making practice more realistic and adaptable compared to systems with predefined responses.
    - **How it works at a high level:**
        1.  **Explore:** Player navigates the map (Flame).
        2.  **Speak:** Player uses microphone; audio is processed by STT (iApp SpeechFlow / Whisper) into Thai text.
        3.  **Process:** Thai text, along with conversational context and NPC persona, is sent to an LLM (GPT-4o / Claude 3) to generate an NPC reply and a "charm delta" (how the interaction affected the relationship).
        4.  **Respond:** The NPC's reply is voiced using TTS (PlayHT / Google Cloud TTS) and displayed in a speech bubble in Thai, with optional English subtitles and transliteration.
        5.  **Progress (Quest):** If a quest objective is met (e.g., dish collected), the game progresses, potentially triggering a spaced-repetition flash-card review (FlutterFlow).
        6.  **Practice (Premium):** The "Practice-Anytime" chat screen uses this same pipeline, additionally retrieving and incorporating relevant long-term memories for the NPC.

**5. Gamification and Learning Reinforcement:**
    - **What it does:** Incorporates game mechanics to motivate players and reinforce learning.
    - **Why it's important:** Increases engagement and helps with knowledge retention.
    - **How it works:**
        -   **Charm/Friendship Score:** Successfully navigating conversations increases a "charm" score with NPCs, potentially unlocking new dialogue or information.
        -   **Quest Progression:** Completing conversational objectives within quests advances the storyline and unlocks new areas or content.
        -   **Rewards and Points:** XP, skill points (for listening/speaking/vocab), and in-game currency can be earned for successful interactions, redeemable for cosmetic items or bonus content.
        -   **Conversation Challenges:** Special modes like "Time Attack" or "Mystery Word" to test skills under pressure.
        -   **Adaptive Difficulty & Hinting:** NPCs may offer hints or simplify language if the player struggles.
        -   **Story Arcs & Vocabulary Targets:** Chapters themed around specific vocabulary sets, ensuring natural repetition.
        -   **Spaced Repetition System (SRS):** After key interactions or quest completions, players engage in flash-card reviews (built with FlutterFlow) to reinforce learned vocabulary.
        -   **Boss Battles:** End-of-chapter boss fights that test pronunciation skills in a high-stakes, engaging format, providing a clear goal for players to work towards.

**6. Thai Transliteration & Grammar Highlighting:**
    - **What it does:** Provides visual aids to help learners understand spoken and written Thai.
    - **Why it's important:** Supports beginners unfamiliar with Thai script and helps learners recognize grammatical patterns.
    - **How it works:**
        -   Dialogue is displayed in Thai script with an optional toggle for Romanized transliteration (RTGS or phonetic).
        -   Parts of speech (nouns, verbs, particles) can be color-coded in the displayed text to highlight sentence structure.
        -   Users can customize these aids (always on, on tap, or off).

**7. Pedagogical Approach:**
    - **Active Recall:** Players actively produce language by speaking, not just selecting from options.
    - **Spaced Repetition:** Integrated flash-card reviews and recurring vocabulary in new contexts.
    - **Contextual Immersion:** Learning occurs in simulated real-world locations and scenarios with culturally relevant NPCs.
    - **Immediate Feedback & Adaptation:** AI NPCs respond dynamically, and the game provides immediate feedback on communication success (e.g., charm points, quest progression).

**8. Pronunciation-Based Boss Fights:**
    - **What it does:** At the end of a chapter or major questline, players face a "boss" character in a turn-based battle. Success in the battle is determined by the player's pronunciation accuracy when speaking specific Thai words or phrases.
    - **Why it's important:** This feature serves as a dynamic skill check, motivating players to master the vocabulary they've learned. It gamifies the learning assessment process, making it more engaging and rewarding than a standard quiz.
    - **How it works:**
        -   Players enter a special boss fight screen with a unique background and boss character (e.g., the "Tuk-Tuk Monster").
        -   In player turns, they are prompted with a word or phrase to pronounce. The app records and assesses their pronunciation using an AI service.
        -   The pronunciation score (accuracy, fluency, etc.) is converted into attack power. Higher scores result in more damage to the boss.
        -   In the boss's turn, the player might be prompted to pronounce a defensive phrase. Good pronunciation reduces incoming damage.
        -   The battle uses a turn-based system, with health bars for both the player and the boss.
        -   Winning the boss fight unlocks significant rewards and progresses the story.
        -   After the battle, players receive a detailed report on their performance, including average pronunciation scores and words that need to practice.

# User Experience

**1. Target Audience & Personas:**
    - **Primary:** English-speaking travelers planning a trip to Thailand, or those interested in Thai language and culture.
    - **Secondary:** Language learning enthusiasts looking for new, engaging methods.
    - **Assumed Skill Level:** Beginner to lower-intermediate Thai learners.
    - **NPC Personas:** Characters reflect everyday Thai individuals (street food vendors, taxi drivers, shopkeepers) with distinct personalities, speaking styles (formal/informal, slang), and backstories to make interactions authentic and culturally rich. **Their facial expressions will dynamically change based on the player's charm score with them.**

**2. User Journey & Key Flows:**
    - **Onboarding:** Simple tutorial explaining voice interaction, UI elements, and quest objectives. Managed by FlutterFlow screens.
    - **Quest Gameplay:**
        -   Player receives a quest objective (e.g., "Collect Guay Jub from Ouan Pochana stall").
        -   Player navigates the **2D side-scrolling Yaowarat at Night map** (Flame engine) to the relevant NPC.
        -   Player initiates conversation by tapping a microphone icon and speaking.
        -   AI pipeline processes speech and generates NPC response (voice + text).
        -   Player continues conversation, aiming to use target phrases correctly to build charm and complete objectives.
        -   Successful interaction leads to reward (e.g., virtual dish item, charm points).
    - **Boss Fight:**
        -   At the end of a questline, the player might encounter a portal leading to a boss fight.
        -   The player engages in a turn-based battle where pronunciation accuracy determines attack and defense effectiveness.
        -   Winning the fight yields significant rewards and story progression.
    - **Practice-Anytime Chat (Premium):**
        -   Player selects an unlocked NPC from a menu.
        -   Engages in open-ended conversation, with the AI recalling past interactions.
    - **Spaced Repetition:**
        -   After collecting a dish or completing a quest segment, a flashcard-style review of key vocabulary is presented (FlutterFlow).
    - **Settings & Customization:**
        -   Players can adjust audio volume, toggle subtitles/transliteration, and manage their account/subscription (FlutterFlow screens).

**3. UI/UX Considerations:**
    - **Art Style:** Initial prototypes for both retro pixel art and vibrant hand-drawn 2D art. The final style will be chosen for its appeal, clarity, and performance on mobile devices, **with a strong emphasis on making the Yaowarat at Night setting visually stunning, leveraging its unique lighting and atmosphere.**
    - **Visual Feedback:** Clear indication of active listening (mic icon), NPC speaking, and charm level changes. **NPC character sprites will display different facial expressions (angry, annoyed, neutral, beaming) corresponding to the current charm score percentage.** Speech bubbles will display Thai script, optional transliteration, and optional English translation.
    - **Accessibility:**
        -   Thai speech bubbles with optional English subtitles.
        -   Volume controls.
        -   Color-blind-friendly palette for UI elements and grammar highlighting (configurable in settings).
    - **Intuitive Controls:** Simple tap-to-move or joystick for map navigation. Clear microphone button for initiating speech.
    - **Non-Intrusive Monetization:** Premium features clearly gated. Limited, optional rewarded ads for free users if implemented.

# Technical Architecture

**1. System Components & Layers:**

| Layer          | Technology Chosen           | Alternatives Considered                  | Notes                                                                    |
|----------------|-----------------------------|------------------------------------------|--------------------------------------------------------------------------|
| **Game Engine**  | Flutter + Flame             | React Native + Canvas/Game Engine, Unity | Flutter/Flame for rapid cross-platform **2D side-scrolling** dev, UI flexibility.         |
| **No-Code UI** | FlutterFlow                 | Pure Flutter widgets                     | For onboarding, settings, SRS, paywall – faster iteration.               |
| **STT**          | iApp SpeechFlow / Whisper   | Google Cloud STT, Vosk                   | Whisper for accuracy & cost. iApp SpeechFlow as potential alternative.     |
| **TTS**          | PlayHT / Google Cloud TTS   | ElevenLabs, Azure/Polly TTS, Native OS TTS | Google TTS (WaveNet) for quality/cost. PlayHT for voice variety.         |
| **AI Dialogue**  | GPT-4o / Claude 3           | GPT-3.5 Turbo, Gemini, Self-hosted LLMs  | GPT-4o/Claude 3 for quality, context handling, and persona consistency.  |
| **Backend**      | FastAPI on Fly.io           | Firebase Functions, Node.js/Express, Render, DigitalOcean App Platform      | FastAPI for Python AI library integration, performance. Fly.io chosen for global distribution & scale-to-zero, Render/DOAP are viable alternatives. |
| **Database**     | Supabase (PostgreSQL)       | Firebase Firestore, Self-hosted Postgres | Supabase for integrated auth, DB, storage, and Vector support.           |
| **Vector Store** | pgvector (via Supabase)     | Pinecone, Weaviate                       | For long-term NPC memory retrieval, integrated with main DB.             |
| **Analytics**    | Supabase Edge + OpenTelemetry | Mixpanel, Amplitude, Firebase Analytics  | For KPI tracking, leveraging Supabase's capabilities.                    |

**2. AI Speech Conversation Pipeline (Detailed):**
    1.  **Client (Flutter App):** Player taps mic icon. App records audio.
    2.  **Audio Transmission:** Audio data sent to backend (or directly to STT service if secure).
    3.  **STT Service (Whisper/iApp SpeechFlow):** Converts audio to Thai text.
    4.  **Backend (FastAPI):**
        *   Receives Thai text from STT.
        *   (Optional) Translates Thai text to English for LLM processing if LLM performs better with English prompts.
        *   Constructs LLM prompt: Includes NPC persona, conversation history (short-term), retrieved long-term memories (for premium chat), and the player's latest message. **The prompt will guide the LLM to assess if the player's message should modify the charm score based on tone and content (friendliness, rudeness, etc.).**
        *   Sends prompt to LLM Service (GPT-4o / Claude 3).
    5.  **LLM Service:** Generates NPC reply text (ideally in Thai, or English if translation is used).
    6.  **Backend (FastAPI):**
        *   Receives LLM reply.
        *   (Optional) If LLM replied in English, translates it back to Thai.
        *   Calculates "charm delta" based on interaction.
        *   Stores/updates short-term conversation history and long-term memories (if applicable).
        *   Sends Thai reply text (and charm delta) back to the client.
    7.  **Client (Flutter App):**
        *   Receives Thai reply text.
        *   Displays Thai text in speech bubble (with optional transliteration/English subtitle).
        *   Sends Thai text to TTS Service (PlayHT / Google Cloud TTS).
    8.  **TTS Service:** Converts Thai text to speech audio.
    9.  **Client (Flutter App):** Plays NPC's voice audio. Updates charm gauge.

**3. Data Models (Simplified):**
    -   **Users:** `user_id`, `email` (optional), `subscription_status`, `premium_until`, `settings_json`.
    -   **NPCs:** `npc_id`, `name`, `persona_description_yaml`, `location_id`.
    -   **Quests:** `quest_id`, `title`, `description`, `chapter_id`, `required_npc_interactions_json`.
    -   **PlayerProgress:** `user_id`, `quest_id`, `status`, `current_step`, `inventory_json` (collected items).
    -   **Memories (for Premium Chat):** `memory_id`, `user_id`, `npc_id`, `interaction_timestamp`, `conversation_chunk_text`, `embedding_vector` (pgvector).
    -   **Vocabulary:** `vocab_id`, `thai_word`, `romanization`, `english_translation`, `part_of_speech_tag`.
    -   **SRSEntries:** `user_id`, `vocab_id`, `last_reviewed_timestamp`, `next_review_timestamp`, `ease_factor`.

**4. APIs and Integrations:**
    -   **Internal API (FastAPI):** Endpoints for `/dialogue`, `/auth`, `/user_progress`, `/memory_store_retrieve`.
    -   **External APIs:**
        -   OpenAI API (Whisper, GPT-4o) / Anthropic API (Claude 3)
        -   Google Cloud APIs (Speech-to-Text, Text-to-Speech, Translate)
        -   PlayHT API (TTS)
        -   iApp SpeechFlow (STT - if chosen)
        -   Supabase SDK (for direct client-DB interactions where appropriate, e.g., auth, user settings).
        -   **App Store Connect API / Google Play Developer API (for subscription status/validation).**
        -   **Stripe API (for backend receipt validation with app store payments).**

**5. Infrastructure Requirements & Scalability:**
    -   **Backend Hosting (Fly.io):** Start with a small container, scalable based on load. Fly.io allows deploying containers close to users and offers scale-to-zero capabilities. Alternatives like Render or DigitalOcean App Platform can also be considered for their PaaS offerings.
    -   **Database (Supabase):** Managed service, scales with pricing tiers. pgvector for similarity search on memories.
    -   **AI APIs:** Usage-based, inherently scalable. Monitor costs and rate limits.
    -   **Content Delivery:** Game assets (images, audio files not dynamically generated) can be bundled with the app or served via Supabase Storage/CDN.
    -   **Offline Capabilities:** MVP is online-only due to AI reliance. Future considerations for limited offline mode (e.g., pre-scripted dialogues, SRS review).

**6. Latency & Cost Management:**
    -   **Latency:** Aim for <3-5 seconds per conversation turn. Optimize by:
        -   Streaming STT/TTS where possible.
        -   Choosing faster LLM variants for non-critical interactions (e.g., GPT-3.5 Turbo for free tier practice if GPT-4o is too slow/costly).
        -   Caching common NPC responses or pre-generating some dialogue elements.
    -   **Cost:** API costs are the primary concern.
        -   Implement freemium model to offset costs with subscriptions.
        -   Limit free tier usage (e.g., number of conversations/day).
        -   Offer premium tier with higher quality/faster LLMs.
        -   Continuously evaluate and optimize API usage (e.g., shorter prompts, batching requests if applicable). Research plan estimates \$20-\$80/day for 1000 DAU depending on model choices.

# Development Roadmap

**1. MVP Requirements (30-Day Solo Dev Sprint Target):**
    -   **Phase 1: Foundations & Art Style (Week 1)**
        -   **Infrastructure Setup:** Git repository with CI/CD basics, FlutterFlow project, Supabase project linked, basic Flame game scaffold, FastAPI backend container.
        -   **Art Style Exploration & Lock-in:** Create sample pixel art AND vibrant hand-drawn 2D tiles/NPCs. Import into Flame. Conduct review and finalize art direction.
    -   **Phase 2: Core Loop Integration (Week 2)**
        -   **Map & Movement:** Build the **single, side-scrolling Yaowarat at Night Tiled map**; implement player avatar movement (left/right, simple interactions), map scrolling, and basic collision detection in Flame.
        -   **FlutterFlow-Flame Bridge:** Embed Flame `GameWidget` into FlutterFlow. Develop onboarding screens, user authentication flow (Supabase Auth), and basic settings screens in FlutterFlow.
        -   **Speech Pipeline POC:** Demonstrate a working end-to-end speech loop: Mic input (SpeechFlow/Whisper) → Text → Basic LLM call (mocked if needed) → Text Output → TTS voice output (PlayHT/Google TTS).
    -   **Phase 3: Dialogue & Learning Systems (Week 3)**
        -   **Conversation UI:** Implement in-game microphone recorder UI, speech bubbles for player and NPC (Thai text + optional subtitles/transliteration), and a visual charm gauge.
        -   **Backend Dialogue Logic:** Define vendor personas (e.g., in YAML files). Create FastAPI `/dialogue` endpoint to manage conversation flow, basic context, and (mocked) NPC memory retrieval.
        -   **Learning Systems:** Implement charm point system, basic inventory for collected quest items. Script the Yaowarat vendor interactions for the starter quest. Develop SRS flash-card UI and logic in FlutterFlow.
    -   **Phase 4: Premium Features, Polish, & Launch Prep (Week 4)**
        -   **Subscription & Unlocks:** Integrate with **App Store/Google Play in-app purchase systems**. Use **Stripe for backend receipt validation**. Implement paywall to gate "Practice-Anytime" chat and future quests in FlutterFlow.
        -   **QA & Performance:** Achieve ≥80% unit/widget test coverage. Conduct thorough QA on target iOS devices. Optimize assets and game performance.
        -   **Release & Marketing Prep:** Create App Store assets (screenshots, preview video), write privacy policy. Target TestFlight build by Day 28. Prepare 5 initial TikTok/Instagram reels and a simple landing page.
    *Reserve 2 buffer days for unforeseen blockers within the 30-day schedule.*

**2. Future Enhancements (Post-MVP):**
    -   **New Cities & Languages:** Expand with new downloadable quest chapters (e.g., Tokyo/Japanese, Paris/French).
    -   **Advanced NPC Memory & Interaction:** More sophisticated long-term memory, NPC-to-NPC interactions, dynamic NPC schedules.
    -   **Deeper Gamification:** Leaderboards, achievements, customizable avatars, more complex quest types.
    -   **Community Features:** Share progress, user-generated content (e.g., custom conversation scenarios - with heavy moderation).
    -   **Enhanced Learning Tools:** Pronunciation scoring, advanced grammar explanations, personalized learning paths.
    -   **Offline Mode:** Limited offline practice with pre-scripted dialogues or simpler AI.
    -   **Web & Desktop Versions:** Leverage Flutter's multi-platform capabilities.
    -   **Localization of Marketing Materials:** Adapt promotional content for new language markets.

# Logical Dependency Chain (MVP Focus)

1.  **Core Infrastructure:** Git, CI, Supabase, Flutter (+Flame/FlutterFlow) project setup.
2.  **Art Style Decision:** Must be locked early as it impacts all visual asset creation **for the Yaowarat at Night map.**
3.  **Basic Player Movement & Side-Scrolling Map (Yaowarat at Night):** Needed before any interaction can occur.
4.  **Authentication & User State:** Required to save progress and manage premium status.
5.  **Speech-to-Text & Text-to-Speech Integration (POC):** Fundamental for voice interaction.
6.  **LLM Integration (POC for Dialogue Generation):** Core of the conversational AI.
7.  **Conversation UI:** Speech bubbles, mic button – essential for player interaction.
8.  **Quest Scripting (Yaowarat):** Defines the MVP content and flow.
9.  **Learning Systems (Charm, SRS):** Integrate with quest progression.
10. **Monetization Backend (App Store/Play Store IAP, Stripe for validation):** Needed to test premium feature gating.
11. **Premium Feature Implementation ("Practice-Anytime" Chat):** Build upon core dialogue system.
12. **QA, Polishing, Asset Optimization:** Final steps before TestFlight.
13. **App Store Submission Assets & Documentation:** Required for release.

*Development should prioritize getting a functional end-to-end loop for one quest interaction as quickly as possible, then layer on features and content.*

# Risks and Mitigations

| Risk                                      | Mitigation Strategy                                                                                                   |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| **STT Mis-recognition / Accuracy**        | Use high-quality STT (Whisper). Offer a "retry" or "type input" option as fallback. Explore alternate STT providers if issues persist. |
| **LLM Latency / Unpredictable Responses** | Pre-warm LLM instances if possible. Implement strict timeouts. Have fallback/canned NPC responses for errors. Optimize prompts. Consider faster/cheaper LLM tiers for less critical dialogue. |
| **FlutterFlow–Flame Integration Issues**    | Prototype the bridge for `GameWidget` embedding and communication early (Week 1-2). Simplify data passing if needed.      |
| **App Store Rejection (Privacy/AI)**      | Thoroughly document data usage in privacy policy. Clearly explain microphone and AI usage. Implement content moderation for AI-generated dialogue. Comply with Apple's latest AI disclosure rules. |
| **API Costs Exceeding Projections**       | Monitor usage closely. Optimize API calls (batching, caching). Adjust free tier limits. Price subscription to cover costs. Explore cheaper API alternatives or self-hosting if scale justifies. |
| **Maintaining NPC Persona Consistency**   | Robust prompt engineering with persona details. Few-shot examples in prompts. Store and re-inject key NPC characteristics. |
| **Scope Creep / Solo Dev Overload**       | Stick rigidly to MVP features for 30-day sprint. Defer non-essential features. Utilize low-code (FlutterFlow) where possible. |
| **Ensuring Learning Efficacy**            | Base pedagogy on research (active recall, SRS). Beta test with target users and gather feedback on learning effectiveness. Track learning KPIs. |
| **Art Style Production Bottleneck**       | Lock style early. Leverage AI (Midjourney) for concept art/initial assets if compatible with final style, then refine manually or with artists. |

# Appendix

**1. Goals & Success Metrics (from PRD v0.5):**
    *   **MVP Goals:**
        *   Ship iOS TestFlight build in 30 days (Internal QA pass: Target ✅ Day 30)
        *   Voice loop accuracy: Thai STT ≥ 90% word accuracy
        *   Learning efficacy: 70% of beta users recall 80% vocab after 1 week
        *   Engagement: D7 retention ≥ 25%
    *   **Recommended KPI Suite:**
        *   Engagement: Avg. daily session length, Avg. phrases practiced/session
        *   Funnel: Onboarding completion rate
        *   Gameplay: Conversation completion rate (charm achieved)
        *   Premium: Practice Chat Depth, Paywall Conversion Rate
        *   AI Memory: Memory Recall Hit Rate (for premium chat)
        *   Expansion: Cross-City D7 Retention (for future quests)
        *   Tech: STT error rate, API latency, Crash-free sessions

**2. Monetization Model & Premium Features (Summary):**
    *   **Freemium Model:**
        *   **Free Tier:** Access to Bangkok (Yaowarat) starter quest, daily Spaced Repetition System (SRS) drills, limited "Practice-Anytime" chat messages (e.g., 2 per NPC/day). May include optional rewarded ads.
        *   **Premium Tier (IAP via App Store/Play Store / Subscription ~\$10-15/mo):**
            *   Unlimited "Practice-Anytime" chat with extended NPC memory.
            *   Automatic access to all future city quests (e.g., Tokyo, Paris).
            *   Exclusive cosmetic rewards for avatar/UI.
            *   Advanced learning analytics.
            *   Access to higher-tier AI models (e.g., GPT-4o/Claude 3 for all interactions vs. potentially faster/cheaper model for free tier).
            *   Detailed post-conversation analysis and AI grammar explanations.
            *   No ads.
    *   Rationale: Balances providing value to free users to build a base, while offering compelling features to drive subscriptions needed to cover ongoing AI API costs and fund further development.

**3. Existing Language Learning Games & Apps (Competitive Landscape Summary):**
    *   **Duolingo Roleplay:** Text-based AI chat. Babbelon differentiates with full voice interaction and an integrated adventure narrative.
    *   **Mondly VR:** VR immersion but with limited, scripted responses. Babbelon offers open-ended dialogue via generative AI.
    *   **LingoLooper / Gliglish:** Focus on AI conversation practice. Babbelon integrates this into a gamified quest-based world with a storyline, aiming for higher engagement and cultural immersion.
    *   **Key Differentiators for Babbelon:** Full voice interaction, interactive **single-map side-scrolling game world (MVP)** with quests, adaptive AI NPCs for unscripted dialogue, culturally rich scenarios, integrated learning aids (transliteration, grammar highlighting, SRS).
    *   Rationale: Name is clear and game-like. Mascot is unique, visually appealing, and thematically relevant. Branding is designed to be globally adaptable.

**4. Graphics & Audio Asset Strategy (Summary):**
    *   **Graphics:**
        *   Initial exploration of both 16-bit pixel art and vibrant 2D hand-drawn styles.
        *   Midjourney (paid subscription for commercial rights) can be used for concept art, backgrounds, or initial asset generation, to be refined/finalized by an artist or developer to ensure consistency and game-readiness. Output is not copyrightable but licensed for commercial use.
    *   **Music & Sound Effects:**
        *   **Music:** AI music generators (e.g., Soundraw, Mubert, AIVA – with commercial licenses from paid plans) for 16-bit retro-style background tracks. Open-source options like MusicGen if quality and license permit.
        *   **SFX:** Procedural generators (sfxr/bfxr) for classic game sounds (royalty-free). AI SFX generators (e.g., ElevenLabs SFX, Stable Audio) or royalty-free sound libraries for ambient/cultural sounds (e.g., tuk-tuk, market chatter).
        *   All chosen audio tools/assets must have clear commercial use licenses or be royalty-free.

**5. Publishing & Marketing Strategy (iOS MVP - Summary):**
    *   **Publishing (App Store):**
        *   Enroll in Apple Developer Program. Build with latest SDKs (iOS 18+).
        *   Detailed App Store Connect setup (metadata, privacy policy, AI content disclosure, in-app purchases).
        *   Thorough testing via TestFlight.
        *   Prepare high-quality screenshots and an app preview video showcasing voice interaction.
        *   Address microphone usage and data privacy meticulously.
    *   **Marketing (TikTok/Instagram):**
        *   Create short, engaging video content (gameplay clips, funny NPC interactions).
        *   Use relevant hashtags (#learnThai, #languagelearning, #pixelartgame).
        *   Consider influencer collaborations and targeted ads (TikTok Spark Ads, IG Ads).
        *   Build community via challenges and user-generated content.

**6. Branding: Title, Mascot & Icon:**
    *   **Title:** Babbelon
    *   **Mascot:** A friendly and calm capybara, with potential names like "Blabbybara" or "Babblebara." Capybaras are known for their social and relaxed nature, making them an approachable and trendy guide for language learners. The name is a play on "babble" (to speak) and "capybara."
    *   **Icon:** A cute pixel art representation of the capybara mascot (Blabbybara/Babblebara). This should be designed to be engaging and easily recognizable as an app icon.
    *   **Rationale:** The app name "Babbelon" is a creative blend of "babble" (referencing speech and learning to talk) and "Babylon" (evoking a world of languages and ancient knowledge). A capybara mascot provides a unique, friendly, and currently popular face for the app. This combination is more engaging and memorable for a game icon than a literal depiction of ancient Babylon, and "Blabbybara/Babblebara" ties the mascot directly to the app's core theme of communication.

---
*This PRD (v1.0) synthesizes previous planning and research. It should serve as the guiding document for the MVP development sprint.*