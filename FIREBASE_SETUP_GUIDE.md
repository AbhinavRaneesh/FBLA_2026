# Firebase Setup Guide for FBLA 2026 App

## ✅ Prerequisites
Your `google-services.json` file is already in place at `android/app/google-services.json`

## 🔥 Firebase Console Setup Required

### Step 1: Enable Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **fbla-2026-83bb4**
3. Click on **Authentication** in the left sidebar
4. Click **Get Started** if not already enabled
5. Go to **Sign-in method** tab
6. Enable **Email/Password**:
   - Click on **Email/Password**
   - Toggle **Enable**
   - Click **Save**
7. (Optional) Enable **Google** sign-in:
   - Click on **Google**
   - Toggle **Enable**
   - Enter support email
   - Click **Save**

### Step 2: Create Firestore Database

1. In Firebase Console, click on **Firestore Database** in the left sidebar
2. Click **Create database**
3. Choose **Start in test mode** (for development)
   - This allows read/write access for 30 days
4. Select your preferred location (e.g., `us-central`)
5. Click **Enable**

### Step 3: Update Firestore Security Rules

Once Firestore is created, update the rules:

1. Go to **Firestore Database** → **Rules** tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Chapters collection
    match /chapters/{chapterId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Test collection (for debugging)
    match /test/{document=**} {
      allow read, write: if true;
    }
  }
}
```

3. Click **Publish**

### Step 4: (Optional) Enable Firebase Storage

1. Go to **Storage** in the left sidebar
2. Click **Get Started**
3. Choose **Start in test mode**
4. Select your storage location
5. Click **Done**

## 🧪 Testing Firebase Setup

### Option 1: Use the Built-in Firebase Test

1. Run your app
2. Navigate to **Profile** tab
3. Click **Firebase Test** button
4. Check the results:
   - ✅ Firebase Core: Should show "OK"
   - ✅ Firebase Auth: Should show "OK"
   - ✅ Firestore: Should show "OK"
   - ✅ Firestore Write/Read: Should show "OK"
   - ✅ Auth Test: Should create a test user or show "already exists"

### Option 2: Try Creating an Account

1. Run your app
2. Click **Create Account**
3. Fill in your details:
   - First Name: John
   - Last Name: Doe
   - Email: test@example.com
   - Password: password123 (at least 6 characters)
4. Click **Create Account**
5. You should be logged in and navigated to the home screen

## 🔍 Common Issues and Solutions

### Issue 1: "Email/Password authentication is not enabled"
**Solution**: Go to Firebase Console → Authentication → Sign-in method → Enable Email/Password

### Issue 2: "Firestore is currently unavailable"
**Solution**: Go to Firebase Console → Firestore Database → Create database in test mode

### Issue 3: "Permission denied"
**Solution**: 
- Check Firestore security rules
- Make sure you're authenticated
- Rules should allow authenticated users to read/write their own data

### Issue 4: "Operation not allowed"
**Solution**: 
- Enable the authentication method in Firebase Console
- For Google Sign-In, also add SHA-1 fingerprint

### Issue 5: "Configuration not found"
**Solution**:
- Make sure `google-services.json` is in `android/app/`
- Run `flutter clean` and rebuild
- Check that the package name matches: `com.example.fbla_2026`

## ✅ Verification Checklist

- [ ] Firebase project created: `fbla-2026-83bb4`
- [ ] `google-services.json` file in `android/app/` ✅ (Already done)
- [ ] Email/Password authentication enabled
- [ ] Firestore database created
- [ ] Firestore security rules updated
- [ ] App builds without errors
- [ ] Can create new user accounts
- [ ] Can sign in with existing accounts
- [ ] User profiles saved to Firestore

## 📱 Firebase Project Info

- **Project ID**: fbla-2026-83bb4
- **Project Number**: 148418731665
- **Package Name**: com.example.fbla_2026
- **Storage Bucket**: fbla-2026-83bb4.firebasestorage.app

## 🎯 Next Steps

After completing the setup:
1. Test user registration
2. Test user login
3. Verify data is saved in Firestore
4. (Optional) Set up Firebase Cloud Messaging for push notifications
5. (Optional) Set up Firebase Analytics

## 🔗 Useful Links

- [Firebase Console](https://console.firebase.google.com/project/fbla-2026-83bb4)
- [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- [Cloud Firestore Docs](https://firebase.google.com/docs/firestore)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)

