# FBLA Member App

**FBLA Competitive Event — Mobile Application Development (2025–2026)**
**Topic: *Design the Future of Member Engagement***

A cross-platform Flutter application that serves as a concept for the official FBLA
member app — helping students stay connected, informed, and engaged with FBLA, its
events, and its broader community. Runs on **Android, iOS, Web, and Windows**.

> Educational project for the FBLA Mobile Application Development competitive event.
> Not affiliated with or endorsed by FBLA, Inc. "FBLA" and the FBLA logo are
> trademarks of Future Business Leaders of America, Inc. (see *Libraries & Copyright*).

---

## How the app addresses the prompt

The 2025–2026 topic requires five inclusions. Each is fully implemented:

| Required inclusion | Where it lives | Notes |
|---|---|---|
| **Member profiles** | `ProfileScreen`, `EditProfileScreen`, `RankScreen` | Avatar, bio, school/chapter, role; gamified stats (streak, FBLA coins, career rank, badges) |
| **Calendar for events & competition reminders** | `EventsScreen` (`table_calendar`) + `flutter_local_notifications` | Month/week/agenda views, filters, RSVP, and timezone-aware local reminders (1 day / 1 hour before) |
| **Access to key FBLA resources & documents** | `ResourcesScreen` | In-app PDF viewer, guided multi-level courses with progress tracking, study materials |
| **News feed with announcements & updates** | `FeedsScreen`, `NewsFeedScreen` | Chapter/State/National filters, plus a live YouTube feed |
| **Integration with chapter social media** | `InstagramFeedScreen` (in-app WebView), `FeedsScreen` | Instagram rendered **inside the app**; YouTube, Facebook, LinkedIn, X, and Linktree linked out |

Additional engagement features: an **AI Coach** (Gemini-backed chat + roleplay/presentation
practice with rubric feedback), a **member directory** with friend requests and 1:1
messaging, **gamification** (coins, streaks, ranks, badges, leaderboards), and a
**first-run guided tour**.

---

## Architecture

A layered architecture with a clear separation between UI, state, and data:

```
UI (screens/)                    Flutter widgets, one file per screen
        │  reads/writes
State   │   AppState (ChangeNotifier, via provider)   ← app-wide state (MVVM-style view model)
        │   ChatBloc (flutter_bloc)                    ← AI chat feature (BLoC pattern)
        │  calls
Data    │   services/    firebase_service, youtube_service, ml_kit_service, mongodb_service
        │   ai/repos/    chat_repo, gemini_repo  (Repository pattern)
        │  persists to
Backend     Firebase (Auth, Firestore, Storage, Messaging) · Gemini API · SharedPreferences (offline cache)
```

**State management.** `AppState` (a `ChangeNotifier` exposed with `provider`) is the
single source of truth for the Firebase user, FBLA profile, events, news, competitions,
and threads — an MVVM-style view model. The AI chat feature uses the **BLoC pattern**
(`flutter_bloc`) with explicit `ChatInitial → ChatLoading → ChatLoaded/ChatError` states.

**Patterns used.** MVVM (view model via `provider`), BLoC (chat), Repository
(`chat_repo`/`gemini_repo`), and a Service layer wrapping each external integration.

**Data handling & security.**
- User and app data persist in **Cloud Firestore**; profile images in **Firebase Storage**.
- **Offline cache:** events and news are cached to `SharedPreferences` on each successful
  load and restored automatically when the network is unavailable — designed for the
  unreliable-venue-WiFi scenario the competition guidelines warn about.
- **Secrets are never committed.** External connection strings are injected at build time
  via `--dart-define` (see below), not stored in source.
- Input is validated on both **syntactic** and **semantic** levels — see
  [`lib/utils/validators.dart`](lib/utils/validators.dart).

### Documentation

Full design and process documentation lives in [`docs/`](docs):

| Doc | Contents |
|---|---|
| [PLANNING.md](docs/PLANNING.md) | Requirements analysis, personas, information architecture, **UML**, **flowchart**, user-journey map, data model |
| [WIREFRAMES.md](docs/WIREFRAMES.md) | High-fidelity **UI mockups** of all primary screens with design rationale |
| [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Brand colors, typography, components, spacing, accessibility tokens |
| [PROJECT_PLAN.md](docs/PROJECT_PLAN.md) | Development timeline, **requirements traceability matrix**, risk log |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Testing strategy + the 54-test automated suite and manual checklist |
| [DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md) | One-page timed judge walkthrough + anticipated Q&A |

---

## Tech stack

- **Framework:** Flutter (Dart), SDK `>=2.18.0 <4.0.0`
- **State:** `provider` (app state) + `flutter_bloc` (chat)
- **Backend:** Firebase — Auth, Firestore, Storage, Messaging
- **Auth:** Firebase Auth + Google Sign-In
- **AI:** Google Gemini API
- **Local storage:** `shared_preferences`, `hive`
- **Media/docs:** `syncfusion_flutter_pdfviewer`, `video_player`, `youtube_player_flutter`, `webview_flutter`, `cached_network_image`

### Brand theming
- `fblaNavy = #00274D` (primary) · `fblaGold = #FDB913` (accent) · `fblaBlue = #1D4E89`

---

## Project structure

```
lib/
  main.dart                  # Entry point, AppState (ChangeNotifier), routing, home/events/feeds/profile
  models/                    # Event, NewsItem, Competition, FBLAUser, rank system, video model
  screens/                   # One file per screen (login, signup, resources, chatbot, profile, …)
  services/                  # firebase_service, youtube_service, ml_kit_service, mongodb_service
  utils/                     # validators.dart (centralized syntactic + semantic validation)
  ai/                        # BLoC-based AI chat: bloc/, models/, repos/ (Gemini), utils/
assets/                      # Logos, coin icon, competition PDFs, media
docs/                        # PLANNING.md + design diagrams
```

---

## Getting started

### Prerequisites
- Flutter SDK (stable channel) and the Android/iOS/Windows toolchains
- A Firebase project (the app reads `lib/firebase_options.dart`)

### Firebase config (not committed)
Add your own Firebase config files from the Firebase console:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### Install & run
```bash
flutter pub get

# Run on a connected device / emulator.
# MONGODB_URI is optional — the app runs fully on Firebase without it.
flutter run --dart-define=MONGODB_URI="<your-mongodb-connection-string>"
```

> **Secrets:** never hardcode connection strings or API keys in source. Pass them with
> `--dart-define=KEY=VALUE` at build/run time.

### Build
```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build windows    # Windows
```

### Quality checks
```bash
flutter analyze
flutter test
```

---

## Accessibility

- All interactive controls expose screen-reader labels (`Semantics` / `Tooltip` /
  `BottomNavigationBarItem` labels), verified via the Android accessibility tree.
- The UI honors the OS **text-scaling** setting (no hardcoded `textScaler` clamp).
- Light and dark themes with brand-consistent contrast.

---

## Libraries & Copyright

All third-party code and assets are documented below for copyright compliance.

### Open-source packages (from `pub.dev`)

| Package | Purpose | License* |
|---|---|---|
| flutter, cupertino_icons | UI framework & icons | BSD-3 / MIT |
| provider | App-wide state management | MIT |
| flutter_bloc, bloc | BLoC state management (AI chat) | MIT |
| shared_preferences | Local key/value storage & offline cache | BSD-3 |
| firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging | Backend (auth, data, files, push) | BSD-3 |
| google_sign_in | Google authentication | BSD-3 |
| table_calendar | Calendar UI | Apache-2.0 |
| flutter_local_notifications | Event reminders | BSD-3 |
| timezone | Timezone-aware scheduling | BSD-2 |
| image_picker, cached_network_image | Image selection & caching | BSD-3 / MIT |
| google_mlkit_image_labeling | On-device image labeling | MIT |
| hive, hive_flutter | Local NoSQL storage | Apache-2.0 |
| webview_flutter | In-app social (Instagram) WebView | BSD-3 |
| youtube_player_flutter | YouTube playback | MIT |
| video_player | Video playback | BSD-3 |
| url_launcher | External links | BSD-3 |
| intl | Date/number formatting | BSD-3 |
| uuid, crypto, http, xml | Utilities | MIT / BSD-3 |
| flutter_lints | Lint rules (dev) | BSD-3 |
| flutter_launcher_icons | App-icon generation (dev) | MIT |
| **syncfusion_flutter_pdfviewer** | In-app PDF viewing | **Syncfusion Community License** (proprietary; free under eligibility terms) |

\* Licenses reflect each package's published license on pub.dev; consult each package for
the authoritative text. The Syncfusion PDF viewer is **not** open source — it is used
under the Syncfusion Community License.

### Services / APIs
- **Google Firebase** — backend (Auth, Firestore, Storage, Messaging).
- **Google Gemini API** — powers the AI Coach and chatbot.
- **YouTube / Instagram** — embedded official FBLA channel content via public feeds/WebView.

### Brand assets & trademarks
- **"FBLA" and the FBLA logo** are registered trademarks of **Future Business Leaders of
  America, Inc.** Used here solely for an educational competition entry; no affiliation or
  endorsement is implied.
- Competition guideline PDFs in `assets/` (`Mobile-Application-Development.pdf`,
  `Cybersecurity.pdf`) are © FBLA, Inc., included for in-app reference only.
- `assets/San Antonio Pictures/` — imagery of the NLC host city; replace with
  properly licensed/attributed photography before any non-educational use.
- App icon, coin icon, and in-app graphics (`logo.png`, `coins.png`, `fbla_logo.png`,
  `fbla_header.png`) are project assets created for this entry; any element derived from a
  third-party source must carry attribution.

---

## License

Educational project for FBLA competition use. Not for commercial distribution.
