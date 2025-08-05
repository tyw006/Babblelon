
# Babblelon: Road to App Store

This document outlines the current state of the Babblelon application, including implemented features, library usage, and a comprehensive roadmap for deployment to the App Store.

## 1. Implemented Features

### 1.1. Onboarding & Main Menu
- **[x] 3D Earth Globe:** Interactive globe for language selection.
- **[x] 2D Thailand Map:** Map with selectable locations (Yaowarat, Chiang Mai, Phuket).
- **[x] Character Selection:** Choose between male and female player sprites.
- **[x] First-Time Playthrough Logic:** Skips character selection on subsequent plays.

### 1.2. Core Gameplay Loop
- **[x] 2D Side-Scrolling World:** Players can navigate a 2D world with a background and player character.
- **[x] NPC Interaction:** Players can interact with non-player characters (NPCs) to initiate dialogue.
- **[x] Dialogue System:** A dynamic dialogue system with the following features:
    - **[x] Speech-to-Text:** Player's speech is transcribed and sent to the backend.
    - **[x] AI-Powered NPC Responses:** NPCs provide dynamic responses based on the conversation history.
    - **[x] Text-to-Speech:** NPC responses are converted to audio and played.
    - **[x] Word-by-Word Analysis:** Dialogue can be broken down into individual words with translations and parts of speech.
    - **[x] Charm System:** Player's charm level with each NPC increases based on interactions.
- **[x] Item System:** Players can receive items from NPCs.
- **[x] Boss Fights:** A turn-based boss fight system with the following features:
    - **[x] Vocabulary-Based Attacks:** Players use vocabulary to attack and defend.
    - **[x] Pronunciation Assessment:** Player's pronunciation is assessed to determine attack/defense effectiveness.
    - **[x] Turn-Based Combat:** Player and boss take turns attacking and defending.
    - **[x] Victory/Defeat Conditions:** The battle ends when the player or boss runs out of health.

### 1.3. Language Learning Features
- **[x] Thai Language Focus:** The initial language is Thai, with a focus on vocabulary and pronunciation.
- **[x] Character Tracing:** Players can practice writing Thai characters.
- **[x] Translation Tools:** In-dialogue tools for translating English to Thai.

## 2. Library Usage

### 2.1. Core Frameworks
- **`flutter`:** The UI toolkit for building the application.
- **`flame`:** A 2D game engine for Flutter, used for the main game screen and boss fights.

### 2.2. State Management
- **`flutter_riverpod` / `hooks_riverpod` / `flame_riverpod`:** A state management library for managing application state in a declarative and reactive way.
- **`provider`:** A dependency injection and state management library.

### 2.3. UI & Animations
- **`flutter_earth_globe`:** A Flutter widget for displaying a 3D interactive globe.
- **`flutter_map`:** A versatile Flutter map widget.
- **`flutter_svg`:** An SVG rendering library for Flutter.
- **`flutter_animate`:** A library for creating beautiful and complex animations.
- **`lottie`:** A library for parsing Adobe After Effects animations exported as json.
- **`animated_text_kit`:** A library for creating animated text effects.
- **`newton_particles`:** A particle system for creating special effects.
- **`animated_flip_counter`:** A library for creating animated flip counters.
- **`google_fonts`:** A package to use fonts from fonts.google.com.

### 2.4. Audio
- **`flame_audio`:** Audio support for the Flame game engine.
- **`just_audio`:** A feature-rich audio player for Flutter.
- **`flutter_sound`:** A complete audio recorder and player for Flutter.
- **`audioplayers`:** A Flutter plugin to play multiple audio files simultaneously.
- **`record`:** A Flutter audio recording plugin.

### 2.5. Data & Storage
- **`shared_preferences`:** A plugin for storing simple data in persistent storage.
- **`isar` / `isar_flutter_libs` / `isar_generator`:** A fast, cross-platform, and easy-to-use database for Flutter.
- **`supabase_flutter`:** A Flutter client for Supabase, used for backend services like authentication and database.
- **`flutter_dotenv`:** A package for loading environment variables from a `.env` file.

### 2.6. Machine Learning
- **`google_mlkit_digital_ink_recognition`:** A Flutter plugin for using Google's ML Kit Digital Ink Recognition API.

### 2.7. Networking
- **`http`:** A package for making HTTP requests.
- **`http_parser`:** A package for parsing HTTP messages.

### 2.8. Utilities
- **`path_provider`:** A Flutter plugin for finding commonly used locations on the filesystem.
- **`permission_handler`:** A Flutter plugin for requesting and checking permissions.
- **`vector_math`:** A library for vector and matrix math.

## 3. Roadmap to App Store

### 3.1. Core Features & Enhancements
- **[ ] User Authentication & Profiles:**
    - **[ ] Implement Supabase Authentication:** Allow users to sign up, log in, and log out.
    - **[ ] Create User Profiles:** Store user data (username, avatar, progress) in Supabase.
    - **[ ] Connect Local & Remote Data:** Sync Isar data with Supabase to persist user progress across devices.
- **[ ] Onboarding & Tutorial:**
    - **[ ] Create a Tutorial:** Guide new users through the core mechanics of the game.
    - **[ ] Introduce the Story:** Set the scene and introduce the player to the world of Babblelon.
- **[ ] Expand Content:**
    - **[ ] Add More Languages:** Implement the "Coming Soon" languages.
    - **[ ] Add More Locations:** Make the Chiang Mai and Phuket locations playable.
    - **[ ] Add More NPCs & Bosses:** Create new characters and challenges for the new locations.
- **[ ] Refine Gameplay:**
    - **[ ] Balance Boss Fights:** Adjust boss health, attack power, and vocabulary difficulty.
    - **[ ] Improve Character Tracing:** Provide more detailed feedback and scoring.
    - **[ ] Enhance Dialogue System:** Add more variety to NPC responses and conversations.

### 3.2. App Store Readiness
- **[ ] App Icons & Splash Screens:**
    - **[ ] Design App Icons:** Create icons for both iOS and Android.
    - **[ ] Create Splash Screens:** Design and implement splash screens for both platforms.
- **[ ] Monetization (Optional):**
    - **[ ] Implement In-App Purchases:** Allow users to purchase cosmetic items or unlock new content.
    - **[ ] Implement Ads:** Integrate ads for non-paying users.
- **[ ] Analytics & Crash Reporting:**
    - **[ ] Integrate Analytics:** Track user engagement and identify areas for improvement.
    - **[ ] Set Up Crash Reporting:** Monitor and fix crashes to ensure a stable user experience.
- **[ ] Legal & Compliance:**
    - **[ ] Create a Privacy Policy:** Inform users how their data is collected and used.
    - **[ ] Create Terms of Service:** Outline the rules and regulations for using the app.
- **[ ] Testing & QA:**
    - **[ ] Conduct Thorough Testing:** Test the app on a variety of devices to identify and fix bugs.
    - **[ ] Beta Testing:** Invite a group of users to test the app and provide feedback.

### 3.3. Deployment
- **[ ] Prepare App Store Listings:**
    - **[ ] Write App Descriptions:** Create compelling descriptions for the App Store and Google Play.
    - **[ ] Take Screenshots & Videos:** Showcase the app's features with high-quality visuals.
- **[ ] Build & Submit:**
    - **[ ] Generate Release Builds:** Create signed builds for both iOS and Android.
    - **[ ] Submit to App Stores:** Follow the submission guidelines for the App Store and Google Play.

## 4. Current Issues & Debug Notes

### 4.1 Audio Loading Issue (2025-07-14) - RESOLVED ✅
- **Issue:** Background music fails to load with error (-11800) when starting the game
- **Root Cause:** Switched from FlameAudio.bgm to just_audio for background music, but just_audio couldn't handle the large 35MB WAV file on iOS
- **Solution:** Reverted to hybrid approach - FlameAudio.bgm for background music, just_audio for sound effects

#### Final Implementation:
- ✅ **FlameAudio.bgm** for background music (35MB WAV file loads successfully)
- ✅ **just_audio** for portal sound effects (160KB MP3, works perfectly)
- ✅ Restored all music control methods (pause, resume, stop) using FlameAudio.bgm
- ✅ Background music now starts properly without iOS audio session errors

#### Performance Benefits:
- FlameAudio is optimized for game background music and handles large files better
- just_audio provides precise control for sound effects and proximity audio
- Hybrid approach gives best performance characteristics for each use case

#### Other Fixes Applied:
1. ✅ Fixed Thailand card styling - all unselected cards now have same background
2. ✅ Added character selection saving to SharedPreferences  
3. ✅ Added comprehensive debugging to track loading sequence
4. ✅ Fixed all print statements to use debugPrint
