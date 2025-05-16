# Babbelon – MVP Product Requirements Document  
*Version 0.5  |  Updated: 2025-05-16*

---

## 1. Executive Summary
**Babbelon** is a **global, voice-only 2-D adventure** that teaches travellers the local language of each city.  
The **MVP** ships the first chapter—**Bangkok / Yaowarat**—for **English speakers learning Thai**. Future downloadable quests will expand to cities like Tokyo and Paris.

The core gameplay is built with **Flutter + Flame**, while **FlutterFlow** powers no-code screens (onboarding, settings, spaced-repetition drills, paywall). Premium subscribers unlock:

* **Unlimited “Practice-Anytime” chat** with extended-memory NPCs  
* **Automatic access to all future city quests & cosmetic rewards**

> **Art direction:** Prototype **retro pixel art** *and* **vibrant hand-drawn 2-D art** in Week 1; lock the final style after review.

---

## 2. Goals & Success Metrics
| Goal | Metric | Target |
|------|--------|--------|
| Ship iOS TestFlight build in 30 days | Internal QA pass | ✅ Day 30 |
| Voice loop accuracy | Thai STT ≥ 90 % word accuracy | ≥90 % |
| Learning efficacy | 70 % of beta users recall 80 % vocab after 1 week | ≥70 % |
| Engagement | D7 retention | ≥25 % |

### Recommended KPI Suite
| Pillar | KPI | Purpose |
|--------|-----|---------|
| Engagement | Avg. daily session length | Detect binge vs. snack use |
| Learning | Avg. phrases practiced/session | Gauge learning volume |
| Funnel | Onboarding completion rate | Spot early drop-off |
| Gameplay | Conversation completion (charm achieved) | Measure quest friction |
| Premium | **Practice Chat Depth** | Success of free-chat feature |
| Premium | **Paywall Conversion Rate** | Freemium health |
| AI Memory | **Memory Recall Hit Rate** | Relevance of memory retrieval |
| Expansion | **Cross-City D7 Retention** | Stickiness of new quests |
| Tech | STT error rate; API latency | Maintain immersion |
| Stability | Crash-free sessions | App quality |

---

## 3. Pedagogical Approach (research-backed)
1. **Active recall via free speech**  
2. **Spaced repetition**  
3. **Contextual immersion** (real locations & vendors)  
4. **Immediate feedback & adaptation**

---

## 4. Yaowarat Starter Quest

### 4.1 Synopsis
Help a Thai food blogger collect three iconic dishes for a “Top 3 Yaowarat Bites” list. Use Thai phrases to charm each vendor and earn their signature dish.

### 4.2 Vendors & Dishes (MICHELIN Bib Gourmand)

| # | Stall | Dish |
|---|-------|------|
| 1 | Guay Jub Ouan Pochana | Peppery rolled-rice noodle soup |
| 2 | Khao Phad Pu Chang Phueak | Crab fried rice |
| 3 | Pa Tong Go Savoey | Crispy dough fritters |

### 4.3 Beginner Keyword Set
*(Each vendor focuses on 3 phrases; ≥2 correct uses unlock progress.)*

| Thai | Romanization | English |
|------|--------------|---------|
| สวัสดี | sa-wàt-dee | Hello |
| ครับ / ค่ะ | khráp / khâ | Polite particle |
| อยากได้... | yàak dâai… | I’d like… |
| เท่าไหร่ | thâo rài | How much? |
| อร่อย | à-ròy | Delicious |
| ไม่ใส่... | mâi sài… | Without… |
| ขอบคุณ | khàwp khun | Thank you |
| อีกหนึ่ง | ìik nʉ̀ng | One more |
| ลาก่อน | laa gòn | Goodbye |

---

## 5. Premium Feature – “Practice-Anytime” Chat
* Unlimited open-ended conversation with any unlocked NPC.  
* Long-term memory stored in Supabase `memories` table (JSONB + pgvector).  
* Free users receive 2 practice messages per NPC/day; paywall gates more.

---

## 6. Core Gameplay Loop
1. **Explore** – Navigate Yaowarat map (Flame).  
2. **Speak** – Mic → STT (iApp SpeechFlow / Whisper) → Thai text.  
3. **Process** – Thai text + context → GPT-4o / Claude 3 → NPC reply + charm delta.  
4. **Respond** – Reply voiced via PlayHT / Google TTS **and** shown in Thai bubble with optional English subtitle.  
5. **Progress** – Dish collected → spaced-repetition flash-card review (FlutterFlow).  
6. **Practice (Premium)** – Free-chat screen uses same pipeline with memory retrieval.

---

## 7. Technical Architecture

| Layer | Tech | Notes |
|-------|------|-------|
| Game | Flutter + Flame | Real-time 2-D quest |
| No-code UI | FlutterFlow | Onboarding, settings, SRS, paywall |
| STT | iApp SpeechFlow • Whisper | Thai speech recognition |
| TTS | PlayHT • Google Cloud TTS | Multiple voices/genders |
| AI | GPT-4o • Claude 3 | Dialogue generation |
| Backend | FastAPI on Fly.io | Auth, LLM proxy, memory |
| DB | Supabase | Users, vocab, memories |
| Vector | pgvector (Supabase) | Long-term memory |
| Analytics | Supabase Edge + OpenTelemetry | KPI tracking |

---

## 8. Monetization
| Tier | Access |
|------|--------|
| **Free** | Bangkok quest, daily SRS, 2 practice messages/day |
| **Premium (IAP / Subscription)** | Unlimited practice chat, **all future city quests**, cosmetics, advanced analytics |

---

## 9. Accessibility
* Thai speech bubbles with optional English subtitles.  
* Volume controls and color-blind–friendly palette via settings.

---

## 10. 30-Day Solo Dev Schedule

| Week | Focus | Tasks | Sub-tasks |
|------|-------|-------|-----------|
| **1** | Foundations & Art Style | **Infra Setup** — Git repo & CI, FlutterFlow project, Supabase link, Flame scaffold, FastAPI container<br>**Art Exploration** — sample pixel & vibrant 2-D tiles/NPCs, import to Flame, style-lock review |
| **2** | Core Loop Integration | **Map & Movement** — build Tiled map, scrolling, collisions<br>**FlutterFlow Bridge** — embed `GameWidget`, onboarding/auth screens, Supabase auth<br>**Speech POC** — SpeechFlow & Whisper, PlayHT & Google TTS demo |
| **3** | Dialogue & Learning | **Conversation UI** — mic recorder, transcript + subtitle bubbles, charm gauge<br>**Backend Dialogue** — vendor personas YAML, `/dialogue` endpoint, memory retrieval<br>**Learning Systems** — charm/inventory, vendor scripting, SRS flash-cards |
| **4** | Premium, Polish, Launch | **Subscription & Unlocks** — Stripe sandbox, paywall, gate practice & quests<br>**QA & Performance** — ≥80 % tests, device QA, asset optimization<br>**Release & Marketing** — App Store assets, privacy docs, TestFlight (Day 28), 5 TikTok/IG reels, landing page |

*Reserve 2 days for unforeseen blockers.*

---

## 11. Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| STT mis-recognition | Alternate provider, retry UX |
| LLM latency | Pre-warm, timeout fallback |
| FlutterFlow–Flame integration issues | Prototype bridge in Week 1 |
| App Store privacy rejection | Comply with mic/data guidelines |

---

## 12. Status
Scope locked. Development sprint begins now.
