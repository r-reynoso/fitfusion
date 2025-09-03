# FitFusion - Professional Fitness Management Platform

[![Deploy Status](https://img.shields.io/badge/deploy-production-green.svg)](https://fitfusion.app)
[![Firebase](https://img.shields.io/badge/Firebase-9.0-orange.svg)](https://firebase.google.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.6+-blue.svg)](https://flutter.dev)

A comprehensive fitness management platform connecting trainers with their clients, built with Flutter and Firebase.

## 🌟 Features

### For Trainers
- **Client Management**: Add, edit, and manage client profiles with metrics tracking
- **Workout Routine Creation**: Build detailed workout routines with exercises, sets, reps, and notes
- **Public Routine Sharing**: Generate shareable links for routines with expiration controls
- **Analytics Dashboard**: Track client progress and routine engagement
- **Secure Authentication**: Role-based access with email verification

### For Clients
- **Personal Dashboard**: View assigned workout routines and personal metrics
- **Progress Tracking**: Monitor weight, height, age, and fitness goals
- **Public Routine Access**: Access shared routines via secure tokens
- **Profile Management**: Update personal information and fitness metrics

## 🚀 Production Deployment

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.6+)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Node.js](https://nodejs.org/) (18+)
- Google Cloud Project with Firebase enabled

### Quick Start

1. **Clone and Setup**
   ```bash
   git clone https://github.com/your-org/fitfusion.git
   cd fitfusion
   chmod +x scripts/*.sh
   ./scripts/setup.sh
   ```

2. **Configure Firebase**
   ```bash
   flutterfire configure --project=fitfusion-prod
   ```

3. **Deploy to Production**
   ```bash
   ./scripts/deploy.sh
   ```

## 🏗️ Architecture

### Frontend (Flutter Web)
- **State Management**: Provider pattern with reactive streams
- **Routing**: GoRouter for declarative navigation
- **UI Framework**: Material Design 3 with custom dark theme
- **Authentication**: Firebase Auth with persistent sessions

### Backend (Firebase)
- **Database**: Cloud Firestore with security rules
- **Authentication**: Firebase Auth with email/password
- **Functions**: Node.js Cloud Functions for admin operations
- **Hosting**: Firebase Hosting with custom domain support
- **Storage**: Cloud Storage for future file uploads

### Security
- **Firestore Rules**: Role-based access control
- **Authentication**: Email verification and password reset
- **Data Validation**: Client and server-side validation
- **HTTPS**: Enforced SSL/TLS with automatic redirects

## 📊 Data Architecture

### Collections

#### `users`
```javascript
{
  id: string,           // Firebase Auth UID
  email: string,        // User email
  role: 'trainer' | 'client',
  name: string,         // Full name
  phone?: string,       // Phone number
  specialization?: string,  // Trainer specialty
  experienceYears?: number, // Trainer experience
  trainerId?: string,   // Client's trainer ID
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `clients`
```javascript
{
  userId: string,       // Reference to users collection
  trainerId: string,    // Reference to trainer
  metrics: {
    weight: number,
    height: number,
    age: number,
    goals?: string,
    gender?: string
  },
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `routines`
```javascript
{
  clientId: string,     // Reference to client
  trainerId: string,    // Reference to trainer
  title: string,        // Routine name
  days: [               // Array of workout days
    {
      day: string,      // Day name
      items: [          // Exercises and dividers
        {
          type: 'exercise' | 'divider',
          name: string,
          reps?: string,
          sets?: string,
          notes?: string,
          label?: string  // For dividers
        }
      ]
    }
  ],
  notes?: string,       // Routine notes
  isPublic: boolean,    // Public sharing enabled
  publicToken?: string, // Sharing token
  publicExpiresAt?: timestamp,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## 🔐 Security & Privacy

- **Role-Based Access**: Trainers and clients have separate permissions
- **Data Isolation**: Users can only access their own data
- **Secure Sharing**: Public routines use time-limited tokens
- **Input Validation**: All user input is validated and sanitized
- **GDPR Compliance**: User data deletion and export capabilities

## 🚨 Monitoring & Analytics

### Cloud Functions
- `deleteClientCascade`: Handles cascading deletes
- `cleanupExpiredTokens`: Removes expired sharing tokens
- `generateAnalytics`: Provides trainer insights
- `healthCheck`: System health monitoring

### Error Handling
- Comprehensive error messages for users
- Server-side error logging and monitoring
- Graceful degradation for offline scenarios

## 🌍 Environment Configuration

### Production
- **Domain**: `https://fitfusion.app`
- **Firebase Project**: `fitfusion-prod`
- **Error Reporting**: Enabled
- **Analytics**: Full tracking

### Development
- **Domain**: `https://dev-fitfusion.web.app`
- **Firebase Project**: `fitfusion-dev`
- **Debug Mode**: Enabled

## 📱 Platform Support

- ✅ **Web**: Full feature support
- 🚧 **Mobile (iOS/Android)**: Coming soon
- 🚧 **Desktop**: Future consideration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed setup
- **Email**: support@fitfusion.app
- **Issues**: [GitHub Issues](https://github.com/your-org/fitfusion/issues)

## 🔄 Version History

- **v1.0.0**: Initial production release
  - Complete trainer/client workflow
  - Routine creation and sharing
  - Firebase integration
  - Production deployment

---

Built with ❤️ using Flutter and Firebase