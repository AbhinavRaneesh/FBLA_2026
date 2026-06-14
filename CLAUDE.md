# FBLA Member App

A Flutter mobile/desktop app for FBLA members. Supports Android, iOS, Web, and Windows.

## Tech Stack

- **Framework**: Flutter (Dart), SDK `>=2.18.0 <4.0.0`
- **State management**: `provider` + `flutter_bloc`
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **Auth**: Firebase Auth + Google Sign-In
- **AI chatbot**: BLoC-based chat with an AI backend (`lib/ai/`)
- **Local storage**: `hive`, `shared_preferences`
- **Notifications**: `flutter_local_notifications`, Firebase Messaging

## Project Structure

```
lib/
  main.dart              # App entry point, AppState (ChangeNotifier), routing
  models/fbla_models.dart # Domain models: Event, NewsItem, Competition, ChatThread, etc.
  screens/               # UI screens
    login_screen.dart
    signup_screen.dart
    onboarding_screen.dart
    firebase_auth_screen.dart
    edit_profile_screen.dart
    chatbot_screen.dart
    news_feed_screen.dart
    resources_screen.dart
  services/
    firebase_service.dart  # Firestore/Auth helpers
  ai/
    bloc/                  # chat_bloc.dart, chat_event.dart, chat_state.dart
    models/chat_message_model.dart
    repos/chat_repo.dart
    utils/constants.dart
```

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build for web
flutter build web

# Build for Android
flutter build apk

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Key Constants / Theming

- `fblaNavy = Color(0xFF00274D)` — primary brand color
- `fblaGold  = Color(0xFFFDB913)` — accent color

## Firebase

The app uses Firebase for auth, Firestore data, storage, and push notifications. Firebase config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) are **not** committed to the repo — you must add them manually from the Firebase console.

## Notes

- Timezone is hardcoded to `America/Denver` in `main.dart`
- `AppState` (a `ChangeNotifier`) is the global state object; it holds the Firebase user, FBLA user profile, events, news, competitions, and threads
- The AI chatbot uses a separate BLoC (`ChatBloc`) — see `lib/ai/`
