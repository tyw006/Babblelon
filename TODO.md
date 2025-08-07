# BabbleOn: Comprehensive Development Roadmap

This document combines the overall project roadmap with UI-specific development tasks for BabbleOn MVP launch.

## 🚨 MVP CRITICAL PATH - Must Have for Launch

### 1. Core Navigation Structure ✅ (3-4 days)
**Status:** Ready to implement - No dependencies
- [ ] Create bottom tab navigation (Home, Learn, Progress, Settings)
- [ ] Implement navigation state management 
- [ ] Connect to existing game flow
- [ ] Handle deep linking for game screens
- [ ] Add navigation animations

### 2. Onboarding Flow ✅ (2-3 days) 
**Status:** Ready to implement - Uses local storage
- [ ] First-time user detection (check IsarService)
- [ ] 3-4 onboarding screens:
  - [ ] Welcome & app purpose
  - [ ] Voice interaction tutorial
  - [ ] Character selection explanation
  - [ ] Get started CTA
- [ ] Store onboarding completion locally
- [ ] Skip option for returning users

### 3. Home Dashboard Screen ✅ (2 days)
**Status:** Ready to implement - Uses local PlayerProfile
- [ ] User stats display (Level, XP, Gold)
- [ ] Continue learning button
- [ ] Daily streak indicator
- [ ] Recent achievements (last 3)
- [ ] Quick access to current lesson

### 4. Settings Screen ✅ (1-2 days)
**Status:** Ready to implement - Uses existing providers
- [ ] Sound effects toggle (gameStateProvider)
- [ ] Background music toggle (gameStateProvider)
- [ ] Motion preferences (motionPreferencesProvider)
- [ ] Language selection
- [ ] About section
- [ ] Privacy policy link
- [ ] Terms of service link

### 5. Basic Progress Screen ✅ (2 days)
**Status:** Ready to implement - Uses MasteredPhrase model
- [ ] Words learned counter
- [ ] Characters mastered counter
- [ ] Total practice time
- [ ] Accuracy trends
- [ ] Simple progress charts

## 🎯 CURRENT STATE: IMPLEMENTED FEATURES

### ✅ Core Gameplay Loop
- **2D Side-Scrolling World:** Players navigate 2D world with background and player character
- **NPC Interaction:** Players can interact with NPCs to initiate dialogue
- **Dialogue System:** Dynamic dialogue with Speech-to-Text, AI responses, TTS, word analysis
- **Charm System:** Player charm level increases based on interactions
- **Item System:** Players can receive items from NPCs
- **Boss Fights:** Turn-based combat using vocabulary and pronunciation assessment

### ✅ Language Learning Features
- **Thai Language Focus:** Vocabulary and pronunciation focused on Thai
- **Character Tracing:** Practice writing Thai characters
- **Translation Tools:** In-dialogue tools for English to Thai translation

### ✅ Technical Infrastructure
- **Database Integration:** ✅ Both Isar (local-first) and Supabase (cloud sync) properly integrated
- **Audio System:** FlameAudio for background music, just_audio for sound effects
- **State Management:** Riverpod with code generation
- **Analytics:** PostHog integration for user tracking
- **Error Reporting:** Sentry integration

## 📊 LIBRARY USAGE & ARCHITECTURE

### Core Frameworks
- **Flutter:** UI toolkit
- **Flame:** 2D game engine for gameplay and boss fights
- **Riverpod/Provider:** State management with code generation

### Data & Storage
- **Isar:** Fast local database (offline-first)
- **Supabase:** Backend services (authentication, cloud sync)
- **SharedPreferences:** Simple persistent storage

### Audio & Media
- **FlameAudio:** Background music (optimized for large files)
- **just_audio:** Sound effects and precise audio control
- **flutter_sound:** Audio recording
- **audioplayers:** Multiple simultaneous audio playback

### UI & Animations
- **Google Fonts, Flutter Animate, Lottie:** Rich UI experience
- **Newton Particles, Animated Text Kit:** Special effects
- **Flutter Earth Globe, Flutter Map:** Interactive geographical elements

### Machine Learning
- **Google ML Kit Digital Ink Recognition:** Character tracing assessment

## 🔧 CLEANUP COMPLETED

### ✅ Database Merge Issues Resolved
- **Fixed duplicate `lastActiveAt` field** in PlayerProfile model
- **Fixed `npcContext` to `discoveredFromNpc`** in vocabulary analytics
- **Removed unused imports** in app_tutorial_step.dart
- **Regenerated code** via build_runner for Riverpod providers and Isar models
- **Added missing assets** (capybara_face.png) to git tracking

### ✅ Model Architecture Clarified
- **`local_storage_models.dart`:** Comprehensive Isar-based models (offline-first)
- **`game_models.dart`:** Simple models for Supabase integration (cloud sync)
- **Proper separation** between local and remote data structures

## 🚀 NEXT DEVELOPMENT PRIORITIES

### Phase 1: Core UI Implementation (Week 1)
1. **Main navigation structure** - Bottom tabs connecting existing game screens
2. **Home dashboard** - User stats, progress, quick actions
3. **Settings screen** - Audio, preferences, about info
4. **Basic progress screen** - Learning statistics and charts
5. **Onboarding flow** - First-time user experience

### Phase 2: Enhanced Features (Week 2)
1. **Achievement system** - Define and track user accomplishments
2. **Enhanced analytics** - Detailed learning progress insights
3. **Guest profile management** - Seamless offline-to-online transition
4. **Premium feature gates** - Monetization preparation

### Phase 3: Authentication & Cloud Features (Week 3)
1. **User authentication UI** - Login, signup, password reset flows
2. **Profile management** - Edit profile, avatar, preferences
3. **Cloud sync indicators** - Show sync status and conflicts
4. **Account upgrade prompts** - Guide users to create accounts

### Phase 4: Monetization (Week 4)
1. **Paywall screens** - Premium subscription offers
2. **In-app purchase integration** - Payment processing
3. **Subscription management** - Handle active subscriptions
4. **Receipt validation** - Secure purchase verification

## 📱 APP STORE READINESS CHECKLIST

### Technical Requirements
- [ ] **App Icons & Splash Screens:** Design and implement for iOS/Android
- [ ] **Privacy Policy:** Required URL for App Store submission
- [ ] **Terms of Service:** Legal document for app usage
- [ ] **Age Rating:** Complete questionnaire for appropriate rating
- [ ] **Screenshots & Videos:** High-quality app store assets
- [ ] **App Descriptions:** Compelling store listings

### Code Quality
- [x] **No Compilation Errors:** ✅ All critical issues resolved
- [x] **Database Integration:** ✅ Local and cloud storage working
- [x] **Code Generation:** ✅ Riverpod and Isar models up to date
- [ ] **Error Handling:** Comprehensive error states and recovery
- [ ] **Performance:** Optimize loading times and memory usage

### Content Requirements
- [ ] **No Placeholder Content:** Remove "coming soon" features
- [ ] **Demo Account:** Working app demonstration for review
- [ ] **Stability Testing:** No crashes or critical bugs

## 🐛 KNOWN ISSUES & NOTES

### Recently Resolved ✅
- **Audio Loading (2025-07-14):** Resolved background music loading with hybrid approach
- **Database Conflicts:** Fixed merge conflicts between UI and database branches
- **Model Duplication:** Clarified separation between local and remote models

### Current Status
- **Build Status:** ✅ App compiles successfully with minor style warnings
- **Dependencies:** All major libraries properly integrated
- **Database:** Both local (Isar) and cloud (Supabase) services functional

### Development Notes
- **Time estimates** assume single developer
- **UI can be built** with mock data first, then connected to real services
- **Focus on iPhone** UI first, iPad optimization later
- **Test on actual devices**, not just simulator
- **Accessibility support** - VoiceOver compatibility

---

**Last Updated:** Post-database merge cleanup - Ready for UI development phase
**Next Action:** Begin Phase 1 core UI implementation with navigation structure