# FitFusion Firebase Production Setup Guide

## Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Name: "FitFusion" (or "fitfusion-prod")
4. Enable Google Analytics (optional)
5. Select/create Analytics account

## Step 2: Enable Authentication
1. In Firebase Console → Authentication → Get Started
2. Go to Sign-in method tab
3. Enable "Email/Password" provider
4. Enable "Email link (passwordless sign-in)" for forgot password

## Step 3: Configure Authentication Settings
1. In Authentication → Settings → User actions
2. Enable "Email enumeration protection" 
3. Set "Password policy" to require strong passwords
4. Under "Authorized domains", add your custom domain (e.g., fitfusion.app)

## Step 4: Set up Firestore Database
1. Go to Firestore Database → Create database
2. Start in "production mode" (we'll set rules later)
3. Choose a location close to your users

## Step 5: Configure Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Clients can only access their own client document
    match /clients/{clientId} {
      allow read, write: if request.auth != null && request.auth.uid == clientId;
      // Trainers can read their clients' data
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'trainer' &&
        resource.data.trainerId == request.auth.uid;
      // Trainers can update their clients' data
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'trainer' &&
        resource.data.trainerId == request.auth.uid;
    }
    
    // Routines access control
    match /routines/{routineId} {
      // Clients can read their own routines
      allow read: if request.auth != null && request.auth.uid == resource.data.clientId;
      // Trainers can read/write routines for their clients
      allow read, write: if request.auth != null && request.auth.uid == resource.data.trainerId;
      // Public routines can be read by anyone if they have valid token
      allow read: if resource.data.isPublic == true && 
        resource.data.publicExpiresAt > request.time;
    }
  }
}
```

## Step 6: Set up Cloud Functions (for cascading deletes)
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Run `firebase login`
3. Run `firebase init functions`
4. Choose TypeScript
5. Install dependencies

## Step 7: Add Web App to Firebase Project
1. In Project Overview → Add app → Web
2. App nickname: "FitFusion Web"
3. Set up Firebase Hosting: ✓ Yes
4. Copy the config object

## Step 8: Configure Custom Domain & SSL
1. In Hosting → Add custom domain
2. Add your domain (e.g., fitfusion.app)
3. Follow verification steps
4. Firebase automatically handles SSL/TLS certificates

## Step 9: Configure Email Settings
1. Go to Authentication → Templates
2. Customize email templates:
   - Password reset
   - Email address verification
3. In Project Settings → General → Public settings
4. Set "Public-facing name" to "FitFusion"
5. Set "Support email" to your support email

## Step 10: Set up Cloud Functions for Admin Operations
Create functions to handle:
- Delete user authentication when client is deleted
- Cascade delete routines when client is deleted
- Email notifications for password resets

## Environment Configuration
After setting up Firebase project, you'll get a config object like:
```javascript
{
  apiKey: "your-api-key",
  authDomain: "fitfusion-prod.firebaseapp.com",
  projectId: "fitfusion-prod",
  storageBucket: "fitfusion-prod.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdefgh"
}
```

## Security Best Practices
1. Enable App Check for production
2. Set up monitoring and alerts
3. Configure backup schedules for Firestore
4. Set up usage quotas and billing alerts
5. Enable audit logging