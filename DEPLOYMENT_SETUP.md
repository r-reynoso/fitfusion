# FitFusion Production Deployment Setup

## 🚀 Automated CI/CD with GitHub Actions

Your FitFusion app is configured for automatic deployment to Firebase when you push to the `main` branch.

## 📋 Required GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add these secrets:

### 1. FIREBASE_SERVICE_ACCOUNT
```json
{
  "type": "service_account",
  "project_id": "fitfusion-prod-2024",
  "private_key_id": "your-private-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nYour-Private-Key-Content\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@fitfusion-prod-2024.iam.gserviceaccount.com",
  "client_id": "your-client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/v1/metadata/x509/firebase-adminsdk-xxxxx%40fitfusion-prod-2024.iam.gserviceaccount.com"
}
```

### 2. FIREBASE_TOKEN
A Firebase CLI token for deployment authentication.

---

## 🔧 Step-by-Step Firebase Console Setup

### Phase 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Project name: `FitFusion Production`
4. Project ID: `fitfusion-prod-2024`
5. Enable Google Analytics (recommended)

### Phase 2: Enable Authentication
1. In Firebase Console → Authentication → Get started
2. Sign-in method → Email/Password → Enable
3. Sign-in method → Email link (passwordless sign-in) → Enable
4. Settings → Authorized domains → Add your custom domain: `fitfusion.app`

### Phase 3: Create Firestore Database
1. Firestore Database → Create database
2. **Production mode** (security rules will be deployed via CI/CD)
3. Choose location closest to your users (e.g., `us-central1`)

### Phase 4: Enable Firebase Hosting
1. Hosting → Get started
2. Skip CLI setup (handled by CI/CD)
3. Add custom domain: `fitfusion.app`

### Phase 5: Generate Service Account Key
1. Project Settings → Service accounts
2. Generate new private key → Download JSON
3. Copy entire JSON content to GitHub secret `FIREBASE_SERVICE_ACCOUNT`

### Phase 6: Get Firebase CLI Token
```bash
# Install Firebase CLI locally
npm install -g firebase-tools

# Login and get token
firebase login:ci

# Copy the generated token to GitHub secret FIREBASE_TOKEN
```

### Phase 7: Configure Email Templates (Production)
1. Authentication → Templates
2. Password reset:
   - Subject: "Reset your FitFusion password"
   - Customize email template with your branding
3. Email verification:
   - Subject: "Verify your FitFusion email"
   - Customize email template

---

## 🔒 Security Configuration

### Firestore Security Rules (Auto-deployed)
```javascript
// Already configured in firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Trainers can manage their clients and routines
    match /routines/{routineId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.trainerId || 
         request.auth.uid == resource.data.clientId);
    }
    
    // Public routines are readable by anyone
    match /public_routines/{routineId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == resource.data.trainerId;
    }
  }
}
```

---

## 🚀 Deployment Process

### Automatic Deployment
1. Push code to `main` branch
2. GitHub Actions automatically:
   - ✅ Builds Flutter web app
   - ✅ Deploys Firebase Functions
   - ✅ Updates Firestore rules and indexes
   - ✅ Deploys to Firebase Hosting
   - ✅ Verifies deployment

### Manual Deployment
Trigger deployment manually:
1. Go to GitHub Actions tab in your repository
2. Select "Deploy FitFusion to Firebase" workflow
3. Click "Run workflow" → "Run workflow"

---

## 🌐 Custom Domain Setup

### Configure fitfusion.app
1. Firebase Hosting → Add custom domain
2. Domain: `fitfusion.app`
3. Follow DNS setup instructions
4. Add these DNS records at your domain registrar:

```
Type: A
Name: @
Value: 151.101.1.195

Type: A  
Name: @
Value: 151.101.65.195

Type: CNAME
Name: www
Value: fitfusion-prod-2024.web.app
```

5. SSL certificate will be automatically provisioned

---

## 📊 Post-Deployment Verification

After deployment, verify these features:

### ✅ Authentication
- [ ] User registration (Trainer/Client)
- [ ] Email verification
- [ ] Login/logout
- [ ] Password reset
- [ ] Session persistence (30 days)

### ✅ Trainer Features
- [ ] Client management (add/delete clients)
- [ ] Routine creation and editing
- [ ] Public routine sharing
- [ ] Client stats viewing

### ✅ Client Features  
- [ ] View assigned routines
- [ ] Update personal stats
- [ ] Access public routine links

### ✅ Data Persistence
- [ ] User accounts persist across sessions
- [ ] Routines save and load correctly
- [ ] Client-trainer relationships maintained
- [ ] Stats updates are saved

---

## 🔍 Monitoring & Analytics

### Firebase Analytics (Included)
- User engagement tracking
- App performance monitoring
- Crash reporting

### Custom Events (Already implemented)
- User registration by role
- Routine creation/sharing
- Client management actions

---

## 🆘 Troubleshooting

### Common Issues:

**Deployment fails at Functions step:**
- Ensure Node.js 18+ is configured
- Check Functions logs in Firebase Console

**Authentication not working:**
- Verify authorized domains include your custom domain
- Check Firebase project ID matches configuration

**Firestore permission denied:**
- Verify security rules deployed correctly
- Check user authentication status

**Custom domain not working:**
- Verify DNS records are correctly configured
- Wait up to 24 hours for DNS propagation
- Check SSL certificate status in Firebase Console

---

## 📞 Support

- **Firebase Documentation**: https://firebase.google.com/docs
- **Flutter Web Deployment**: https://docs.flutter.dev/deployment/web
- **GitHub Actions**: https://docs.github.com/actions

Your FitFusion app is now ready for production deployment with full CI/CD automation! 🎉