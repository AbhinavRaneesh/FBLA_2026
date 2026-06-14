# Project Plan — FBLA Member App

The development process behind the app: how we went from the competition prompt to a shipped,
tested, cross-platform application. Pairs with [PLANNING.md](PLANNING.md) (design/architecture)
and [TEST_PLAN.md](TEST_PLAN.md) (verification).

---

## 1. Methodology

We used an **iterative, milestone-driven** process (lightweight Agile): short build cycles, each
ending in a working app, with design and testing folded into every cycle rather than bolted on at
the end. Work was tracked as a task backlog and the codebase kept runnable at all times so a demo
was always possible.

---

## 2. Development timeline

| Phase | Milestone | Key deliverables | Status |
|---|---|---|---|
| **0 · Discovery** | Understand the prompt | Requirements analysis, personas, success criteria | ✅ Done |
| **1 · Design** | Lock the experience | Information architecture, [UML](diagrams/uml.png), [flowchart](diagrams/flowchart.png), [mockups](WIREFRAMES.md), [design system](DESIGN_SYSTEM.md) | ✅ Done |
| **2 · Foundation** | App skeleton | Flutter project, navigation, `AppState`, theming, Firebase wiring | ✅ Done |
| **3 · Required features** | The 5 inclusions | Profiles, events/reminders, resources, news feed, social integration | ✅ Done |
| **4 · Engagement** | Differentiators | AI Coach, practice + self-record, gamification, member directory | ✅ Done |
| **5 · Hardening** | Quality & resilience | Centralized validation, accessibility pass, offline cache, secret removal | ✅ Done |
| **6 · Memory & tests** | Polish | AI-Coach persistence, practice history, 54-test suite | ✅ Done |
| **7 · Documentation** | Judge-ready docs | README, planning, mockups, design system, test & project plans | ✅ Done |
| **8 · Presentation** | Demo prep | Demo script, offline-safe walkthrough, Q&A prep | ⏳ In progress |

### Gantt (relative)

```
Phase 0  ██
Phase 1    ████
Phase 2      ████
Phase 3        ████████
Phase 4            ██████
Phase 5                ████
Phase 6                  ████
Phase 7                    ███
Phase 8                       ███
         └──────────────────────────▶ time
```

---

## 3. Requirements traceability matrix

Every prompt requirement traced to where it's designed, built, and verified.

| # | Requirement (from prompt) | Design | Implementation | Verification |
|---|---|---|---|---|
| R1 | Member profiles | [Mockup §6](WIREFRAMES.md#6-profile--identity--gamification) | `ProfileScreen`, `EditProfileScreen`, `RankScreen` | Manual checklist |
| R2 | Calendar + competition reminders | [Mockup §3](WIREFRAMES.md#3-events--calendar-rsvp--reminders) | `EventsScreen` + `flutter_local_notifications` | Manual checklist |
| R3 | Access to FBLA resources/documents | [Mockup §4](WIREFRAMES.md#4-resources--courses--documents) | `ResourcesScreen` + Syncfusion PDF viewer | Manual checklist |
| R4 | News feed | [PLANNING §3](PLANNING.md#3-information-architecture) | `FeedsScreen`, `NewsFeedScreen` | Manual checklist |
| R5 | Chapter social media integration | [PLANNING §3](PLANNING.md#3-information-architecture) | `InstagramFeedScreen` (in-app WebView) + links | Manual checklist |
| E1 | AI Coach (engagement) | [Mockup §5](WIREFRAMES.md#5-ai-coach--the-differentiator) | `chatbot_screen`, `event_practice_screen`, `lib/ai/` | `persistence_test.dart` + manual |
| E2 | Gamification (engagement) | [Mockup §6](WIREFRAMES.md#6-profile--identity--gamification) | `FBLARankSystem`, coins/streaks/badges | `rank_system_test.dart` |
| N1 | Input validation (non-functional) | [PLANNING §8](PLANNING.md#8-validation--data-integrity) | `lib/utils/validators.dart` | `validators_test.dart` |
| N2 | Offline resilience (non-functional) | [PLANNING §7](PLANNING.md#7-data-model) | `AppState` cache + signup queue | `persistence_test.dart` |
| N3 | Accessibility (non-functional) | [DESIGN_SYSTEM §6](DESIGN_SYSTEM.md#6-accessibility-tokens) | `Semantics`/`Tooltip`, text scaling | `tap_target_probe_test.dart` |
| N4 | Security / secrets (non-functional) | [README](../README.md#architecture) | `--dart-define`, no secrets in source | Code review |

---

## 4. Risk log

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Unreliable venue Wi-Fi during demo | High | High | Offline cache + offline-signup queue + developer login (no network) |
| Live account creation fails on stage | Medium | High | Dev login bypass; pending-signup queue syncs later |
| AI API key/quota unavailable | Medium | Medium | Graceful fallback to self-assessment; app fully usable without AI |
| Leaked DB credential in git history | Known | High | Removed from source; flagged for rotation in Atlas |
| Cross-platform rendering differences | Medium | Low | Shared design tokens; tested on Android + Windows |

---

## 5. Tools & process

- **Source control:** Git / GitHub (feature branches, descriptive commits).
- **IDE:** VS Code with the Flutter/Dart toolchain.
- **Quality gates:** `flutter analyze` + `flutter test` before each milestone close.
- **Design:** draw.io (UML/flowchart) + hand-authored SVG mockups.
- **Backend:** Firebase console (Auth, Firestore, Storage, Messaging).

---

See also: [PLANNING.md](PLANNING.md) · [WIREFRAMES.md](WIREFRAMES.md) ·
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [TEST_PLAN.md](TEST_PLAN.md) · [README](../README.md)
