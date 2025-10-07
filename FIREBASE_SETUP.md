# FBLA Member App - Firebase Setup Instructions

## Quick Fix for Development

The app is currently configured to work without Firebase for development purposes. The Firebase features are available but will fall back to the original local authentication system.

## To Enable Firebase Features

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: "FBLA Member App"
4. Enable Google Analytics (optional)
5. Create the project

### 2. Add Android App to Firebase

1. In Firebase Console, click "Add app" → Android
2. Enter package name: `com.example.fbla_member_app` (or your actual package name)
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`

### 3. Add iOS App to Firebase (if needed)

1. Click "Add app" → iOS
2. Enter bundle ID: `com.example.fblaMemberApp` (or your actual bundle ID)
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`

### 4. Enable Authentication

1. In Firebase Console, go to "Authentication" → "Sign-in method"
2. Enable "Email/Password" authentication
3. Enable "Google" authentication
4. Add your app's SHA-1 fingerprint for Google Sign-In

### 5. Enable Firestore Database

1. Go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to your users

### 6. Enable Firebase Storage

1. Go to "Storage"
2. Click "Get started"
3. Choose "Start in test mode" (for development)
4. Select a location

### 7. Update Configuration Files

Replace the placeholder values in these files with your actual Firebase project values:

- `android/app/src/main/res/values/values.xml`
- `android/app/src/main/res/values/google-services.xml`

### 8. Update App Code

Once Firebase is properly configured, you can switch to Firebase authentication by changing this line in `lib/main.dart`:

```dart
// In AuthGate class, change:
return const LoginScreen();
// To:
return const FirebaseAuthScreen();
```

## Firebase Features Available

- ✅ **Email/Password Authentication**
- ✅ **Google Sign-In**
- ✅ **User Profile Management**
- ✅ **Chapter Management**
- ✅ **Event Management with RSVP**
- ✅ **News Feed with Real-time Updates**
- ✅ **Resource Management**
- ✅ **Image Upload to Firebase Storage**

## Development Mode

The app currently runs in development mode with:
- Local authentication (email/password stored locally)
- Sample data for events, news, and competitions
- All UI features working without Firebase

This allows you to develop and test the app while setting up Firebase in the background.

## Troubleshooting

### Common Issues:

1. **"Failed to load FirebaseOptions"** - Make sure `google-services.json` is in the correct location
2. **Google Sign-In not working** - Check SHA-1 fingerprint and enable Google Sign-In in Firebase Console
3. **Firestore permission denied** - Check Firestore security rules
4. **Storage upload fails** - Check Firebase Storage security rules

### Getting SHA-1 Fingerprint:

```bash
# For debug builds
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release builds
keytool -list -v -keystore path/to/your/release.keystore -alias your_alias_name
```

## Security Rules (Development)

### Firestore Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // Only for development!
    }
  }
}
```

### Storage Rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true; // Only for development!
    }
  }
}
```

**⚠️ Important:** These rules allow anyone to read/write your database. Use proper authentication rules for production!
