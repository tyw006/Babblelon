# UI Development TODO - BabbleOn MVP

## Overview
This document tracks all UI development tasks for BabbleOn MVP launch. Tasks are categorized by priority and dependencies.

**Legend:**
- ✅ Can build immediately (no dependencies)
- 🔒 Blocked by specific dependency
- 🌐 Requires backend/database setup
- 💰 Requires payment integration  
- 🔑 Requires authentication
- ⏰ Time estimate in parentheses

---

## 🚨 MVP CRITICAL PATH - Must Have for Launch

### 1. Core Navigation Structure ✅ (3-4 days)
**No dependencies - START HERE**
- [ ] Create bottom tab navigation (Home, Learn, Progress, Settings)
- [ ] Implement navigation state management
- [ ] Connect to existing game flow
- [ ] Handle deep linking for game screens
- [ ] Add navigation animations

### 2. Onboarding Flow ✅ (2-3 days)
**No dependencies - Can build with local storage**
- [ ] First-time user detection (check IsarService)
- [ ] 3-4 onboarding screens:
  - [ ] Welcome & app purpose
  - [ ] Voice interaction tutorial
  - [ ] Character selection explanation
  - [ ] Get started CTA
- [ ] Store onboarding completion locally
- [ ] Skip option for returning users

### 3. Home Dashboard Screen ✅ (2 days)
**No dependencies - Uses local PlayerProfile**
- [ ] User stats display (Level, XP, Gold)
- [ ] Continue learning button
- [ ] Daily streak indicator
- [ ] Recent achievements (last 3)
- [ ] Quick access to current lesson

### 4. Settings Screen ✅ (1-2 days)
**No dependencies - Uses existing providers**
- [ ] Sound effects toggle (gameStateProvider)
- [ ] Background music toggle (gameStateProvider)
- [ ] Motion preferences (motionPreferencesProvider)
- [ ] Language selection
- [ ] About section
- [ ] Privacy policy link
- [ ] Terms of service link

### 5. Basic Progress Screen ✅ (2 days)
**No dependencies - Uses MasteredPhrase model**
- [ ] Words learned counter
- [ ] Characters mastered counter
- [ ] Total practice time
- [ ] Accuracy trends
- [ ] Simple progress charts

### 6. App Store Assets 🔒 (2 days)
**Blocked by: UI screens completion**
- [ ] App icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] App preview video (optional)
- [ ] Feature graphic
- [ ] App description copy

---

## 🎯 LAUNCH-READY FEATURES - Nice to Have

### 7. Enhanced Progress Analytics ✅ (3 days)
**No dependencies - Uses local data**
- [ ] Weekly/monthly stats
- [ ] Streaks calendar view
- [ ] Per-character accuracy
- [ ] Learning pace metrics
- [ ] Export progress report

### 8. Achievement System ✅ (2 days)
**No dependencies - Define locally**
- [ ] Achievement definitions
- [ ] Progress tracking logic
- [ ] Achievement badges/icons
- [ ] Notification on unlock
- [ ] Achievement gallery

### 9. Guest Profile Management ✅ (1 day)
**No dependencies**
- [ ] Guest profile creation
- [ ] "Create account" prompts
- [ ] Local data persistence
- [ ] Upgrade benefits display

---

## 💳 MONETIZATION FEATURES

### 10. Premium Paywall Screens 💰 (3 days)
**Blocked by: IAP package setup**
- [ ] Premium benefits screen
- [ ] Subscription options (monthly/yearly)
- [ ] Comparison table (free vs premium)
- [ ] Special offer banners
- [ ] Restore purchases flow

### 11. In-App Purchase Integration 💰 (2 days)
**Blocked by: Apple Developer account setup**
- [ ] Add in_app_purchase package
- [ ] Product ID configuration
- [ ] Purchase flow UI
- [ ] Receipt validation UI
- [ ] Subscription status management

### 12. Premium Feature Gates ✅ (1 day)
**No dependencies - Can mock premium status**
- [ ] Lock icons on premium content
- [ ] "Upgrade to unlock" buttons
- [ ] Limited hearts/lives system
- [ ] Ad placeholder spaces

---

## 🔐 AUTHENTICATION FEATURES

### 13. Authentication UI Screens 🔑 (3 days)
**Soft dependency - Can build UI without backend**
- [ ] Login screen
- [ ] Sign up screen
- [ ] Forgot password screen
- [ ] Email verification screen
- [ ] Loading states
- [ ] Error handling UI

### 14. Sign in with Apple 🔑 (1 day)
**Blocked by: Apple Developer account**
- [ ] Apple sign-in button
- [ ] Integration with auth flow
- [ ] Terms acceptance UI
- [ ] Account linking flow

### 15. Profile Management 🔑 (2 days)
**Blocked by: Authentication implementation**
- [ ] Edit profile screen
- [ ] Avatar selection/upload
- [ ] Username change
- [ ] Email change
- [ ] Password change
- [ ] Delete account option

---

## 🌐 BACKEND-DEPENDENT FEATURES

### 16. Cloud Sync UI 🌐🔑 (2 days)
**Blocked by: Supabase + Authentication**
- [ ] Sync status indicators
- [ ] Manual sync button
- [ ] Conflict resolution UI
- [ ] Last synced timestamp
- [ ] Offline mode indicators

### 17. Leaderboards 🌐🔑 (2 days)
**Blocked by: Database + Authentication**
- [ ] Global leaderboard
- [ ] Friends leaderboard
- [ ] Weekly/monthly views
- [ ] User rank display
- [ ] Filter options

### 18. Social Features 🌐🔑 (3 days)
**Blocked by: Database + Authentication**
- [ ] Friend system UI
- [ ] Challenge friends
- [ ] Share progress
- [ ] Achievement sharing
- [ ] Referral system

---

## 📱 iOS APP STORE REQUIREMENTS

### Mandatory for Submission:
- [ ] Privacy Policy URL (in-app and App Store Connect)
- [ ] Terms of Service URL
- [ ] Age rating questionnaire
- [ ] Export compliance information
- [ ] App category selection
- [ ] Keywords (100 characters max)
- [ ] Support URL
- [ ] Marketing URL (optional)

### Technical Requirements:
- [ ] Build with Xcode 15+ ✅
- [ ] iOS 17 SDK compliance ✅
- [ ] Sign in with Apple (if using social login) 🔑
- [ ] SHA-256 receipt validation (by Jan 2025) 💰
- [ ] App Transport Security compliance

### Content Requirements:
- [ ] No placeholder content
- [ ] No "coming soon" features
- [ ] Working app demo account (if auth required)
- [ ] Proper error handling
- [ ] No crashes or bugs

---

## 🚀 RECOMMENDED DEVELOPMENT ORDER

### Phase 1: Zero-Dependency UI (Week 1)
1. Main navigation structure
2. Home dashboard
3. Settings screen
4. Basic progress screen
5. Onboarding flow

### Phase 2: Local Features (Week 2)
1. Achievement system
2. Enhanced analytics
3. Guest profile
4. Premium gates (mocked)

### Phase 3: Auth UI (Week 3)
1. Login/signup screens
2. Profile management
3. Auth error handling
4. Password reset flow

### Phase 4: Monetization (Week 4)
1. Paywall screens
2. IAP integration
3. Subscription management
4. Receipt validation

### Phase 5: Backend Features (Post-MVP)
1. Cloud sync
2. Leaderboards
3. Social features
4. Real-time updates

---

## 📊 CURRENT STATUS

**Can Start Immediately:**
- ✅ Navigation structure (no blockers)
- ✅ All core screens (using local data)
- ✅ Onboarding flow
- ✅ Settings/preferences

**Blocked Items:**
- 🔒 App Store assets (need screens first)
- 💰 Payment features (need IAP setup)
- 🔑 User profiles (need auth)
- 🌐 Social features (need backend)

**Next Action:** Start with navigation structure and core screens that have no dependencies.

---

## 📝 NOTES

- All time estimates assume single developer
- UI can be built with mock data first
- Local storage (Isar) is already set up
- Design system (space theme) is established
- Focus on iPhone UI first, iPad later
- Test on actual devices, not just simulator
- Keep accessibility in mind (VoiceOver support)

Last Updated: [Current Date]