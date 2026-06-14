# Test Plan — FBLA Member App

How we verify the app works and stays working. The strategy combines **automated unit tests**
for logic, **widget probes** for accessibility, and a **manual verification checklist** for
device-level behavior.

> Current status: **54 automated tests passing** (`flutter test`), plus the manual checklist
> below run on `emulator-5554` (Android, API 36).

---

## 1. Testing strategy

We test at the layer where each risk lives, favoring fast, deterministic tests with no network
or Firebase dependency:

| Layer | What | How |
|---|---|---|
| **Pure logic** | Validators, ranking math, model parsing | Unit tests (no mocks needed) |
| **Local persistence** | Offline cache, chat & practice history, signup queue | Unit tests with mock `SharedPreferences` |
| **Accessibility** | Tap-target sizes | Widget probe test |
| **Device behavior** | Auth, navigation, reminders, camera, offline | Manual checklist |
| **Backend** | Firestore/Auth integration | Manual (excluded from unit scope by design) |

**Why this split:** the highest-value logic (input validation, gamification, offline resilience)
is pure and deterministic, so it earns dense automated coverage. Firebase-dependent paths are
verified manually to keep the automated suite fast and flake-free.

---

## 2. Automated test suite

Run all: `flutter test`. Files live in [`test/`](../test).

### `validators_test.dart` — input validation (27 tests)
Covers every method in [`lib/utils/validators.dart`](../lib/utils/validators.dart):
- **Email** — valid shapes; rejects missing `@`/TLD, spaces, consecutive dots, and each known
  disposable domain (case-insensitive).
- **Password (sign-in)** — required + 6-char floor.
- **New password (sign-up)** — one assertion per policy rule (length, upper, lower, digit, symbol)
  plus a passing strong password.
- **Confirm password** — required / mismatch / match.
- **Name** — rejects blanks, too-short, and digits; custom field label appears in the message.
- **Strength meter** — asserts each `PasswordStrength` tier boundary and its fraction/label.

### `rank_system_test.dart` — gamification (11 tests)
Covers [`lib/models/fbla_rank.dart`](../lib/models/fbla_rank.dart): `rankForCoins` at tier
boundaries, top-tier clamp, `indexForRank`/`tierByName` (case-insensitive, unknown → first),
`progressToNextRank` (0 / halfway / 1.0), and `coinsToNextRank`.

### `models_test.dart` — serialization (7 tests)
`Video.fromPlaylistItem` (well-formed, fallback fields, missing fields without throwing);
`ChatMessageModel` toJson/fromJson incl. the `model→assistant` role mapping; `PracticeRecord`
round-trips for both coach and self-assessment records.

### `persistence_test.dart` — local storage (8 tests)
Uses `SharedPreferences.setMockInitialValues`:
- `ChatHistoryStore` save/load round-trip, system-message stripping, empty-load, clear.
- `PracticeHistoryStore` add/read newest-first, per-event scoping & counts.
- `AppState.savePendingSignup` writes the expected JSON (the offline-signup queue).
- `AppState.login` persists identity and flips `loggedIn`.

### `tap_target_probe_test.dart` — accessibility (1 test)
Measures interactive control sizes on the login screen against the 44pt minimum.

---

## 3. How to run

```bash
flutter test                       # full suite
flutter test test/validators_test.dart   # one file
flutter test --coverage            # with coverage (writes coverage/lcov.info)
flutter analyze                    # static analysis (no errors in app logic)
```

---

## 4. Manual verification checklist (device)

Run on a physical device or emulator before a demo:

- [ ] **Auth:** sign up (strong-password enforced) → land on Home; log out → log back in.
- [ ] **Developer login:** empty email + password → dev mode (no network).
- [ ] **Offline resilience:** enable airplane mode → app still shows cached events/news; sign-up
      shows "saved — will sync" instead of a network error; reconnect → pending signup completes.
- [ ] **Events:** RSVP an event; set a reminder; confirm the local notification fires.
- [ ] **Resources:** open a course, advance a level, open a PDF in the in-app viewer.
- [ ] **AI Coach:** send a message → reply; reopen the screen → history restored; Clear → empties.
- [ ] **Practice:** get AI feedback / save a self-assessment → appears under the **History** tab;
      reopen app → still there; "Practiced N×" increments.
- [ ] **Accessibility:** enable TalkBack → all controls announce labels; bump system font size →
      layouts reflow.
- [ ] **First-run tour:** fresh install shows the tour once; skippable; replayable from More → Help.

---

## 5. Continuous quality

- `flutter analyze` is clean for app logic (only pre-existing third-party deprecation infos remain).
- New features ship with matching unit tests where the logic is pure (e.g., the offline queue and
  AI-Coach memory added in the latest build are covered by `persistence_test.dart`).

See also: [PROJECT_PLAN.md](PROJECT_PLAN.md) · [PLANNING.md](PLANNING.md)
