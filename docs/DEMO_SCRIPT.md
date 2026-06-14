# Judge Demo Script — FBLA Member App

A tight, timed walkthrough for the presentation. Target: **~6 minutes** of demo + Q&A. Run the
app **already launched and logged in** on the device, on Wi-Fi if available — but the script is
written to survive a dropped connection (see *Offline safety* below).

> One-line pitch: *"An official-style FBLA member app that keeps students connected, informed,
> and engaged — with an AI coach that actually remembers them."*

---

## 0 · Setup before you walk up (30s, off-clock)
- App open on the **Home** screen, logged in (use **developer login**: tap LOGIN with both
  fields empty — no network needed).
- Screen brightness up; notifications silenced; volume on for the reminder demo.
- Have a second talking point ready in case Wi-Fi is down (the app still works — lean into it).

---

## 1 · Hook & framing (30s)
> "FBLA asked us to design the future of member engagement. We built a cross-platform app —
> Android, iOS, web, and Windows from one codebase — that delivers all five required features
> and goes further with an AI coach and gamification. Let me show you."

Gesture to the **Home dashboard**: NLC countdown, quick actions, upcoming events, announcements —
*"everything a member needs is one tap from here."*

---

## 2 · The five required features (2.5 min — the core)
Move deliberately; name each requirement as you show it.

1. **Profiles** → open **Profile**: *"Members get a real identity — school, role, and a career
   rank from Intern to CEO driven by FBLA coins and streaks."*
2. **Calendar + reminders** → **Events**: tap a date, **RSVP**, toggle a **reminder**.
   *"Reminders fire as local notifications a day and an hour before — so no one misses a deadline."*
3. **Resources + documents** → **Resources**: open a **course level**, then open a **PDF in the
   in-app viewer**. *"Study materials and the official guidelines never make them leave the app."*
4. **News feed** → **Feeds**: *"Chapter, state, and national announcements, filterable, plus a
   live video feed."*
5. **Social integration** → show **Instagram in-app** (WebView): *"Chapter social lives inside
   the app, not a link out."*

---

## 3 · The differentiator — AI Coach that remembers (1.5 min)
> "Here's what sets us apart."

- Open **AI Coach**, ask: *"How do I prep for Public Speaking?"* → show the structured reply.
- **Close the screen and reopen it** → *"Notice the conversation is still here. The coach
  remembers — it persists on the device."*
- Open a performance event's **Practice** → get **AI feedback** or save a **self-assessment** →
  switch to the **History tab**: *"Practiced 3×" — members see real progress over time.*

> Tie back: *"That's member engagement — not just information, but a reason to come back."*

---

## 4 · Quality & craft (45s — earns the technical rows)
> "Under the hood this is built to compete."

- *"All input is validated on syntactic **and** semantic levels — and we have **54 automated
  tests** covering validation, ranking, persistence, and serialization."* (Offer to run
  `flutter test` live if asked.)
- *"It's accessible — screen-reader labels, 44pt touch targets, and it respects the system font
  size."*
- *"Secrets are never in the source — they're injected at build time."*

---

## 5 · Offline safety (always works on stage) (30s)
> If Wi-Fi is flaky, **make it a feature**:
- *"Conference Wi-Fi is unreliable, so we designed for it. Watch."* → (airplane mode) the app
  still shows cached events and news; a sign-up shows *"saved — will sync when online"* instead of
  an error; reconnecting completes it automatically.

---

## 6 · Close (15s)
> "Five required features, an AI coach that remembers, gamified engagement, real tests,
> accessibility, and offline resilience — a member app ready for FBLA. We'd love your questions."

---

## Anticipated judge Q&A

| Question | Answer |
|---|---|
| *How did you test it?* | 54 automated tests (`flutter test`) + a manual device checklist — see [TEST_PLAN.md](TEST_PLAN.md). |
| *What's your tech stack?* | Flutter/Dart, Provider + BLoC, Firebase (Auth/Firestore/Storage/Messaging), Gemini for AI. |
| *How is data stored / kept safe?* | Firestore is the system of record; offline cache in local storage; secrets via `--dart-define`, never committed. |
| *What was your process?* | Iterative milestones — discovery → design (UML, flowchart, mockups) → build → hardening → docs. See [PROJECT_PLAN.md](PROJECT_PLAN.md). |
| *Is it really cross-platform?* | One codebase targets Android, iOS, web, and Windows. |
| *What would you add next?* | Cloud sync of practice history, push-based event reminders, and a coach that adapts to each member's weak rubric areas. |
| *Did you handle copyright?* | Every library and asset is documented with its license — see the README's Libraries & Copyright section. |

---

## Roles (if presenting as a team)
- **Driver** — holds the device, performs the taps.
- **Narrator** — speaks the script, never reads slides verbatim.
- **Closer** — handles Q&A and the technical/quality answers.

*Practice the path end-to-end at least 3× so the navigation is muscle memory — judges score
confidence and flow.*

See also: [README](../README.md) · [PROJECT_PLAN.md](PROJECT_PLAN.md) · [TEST_PLAN.md](TEST_PLAN.md)
