import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../services/environment_service.dart';

/// Simplified Firebase service for FitFusion
/// Handles initialization and provides unified access to core Firebase services
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  // Firebase service instances
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  // Initialization state
  bool _initialized = false;
  bool _firestoreConfigured = false;

  /// Initialize Firebase with core services
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase App
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize core services
      await _initializeAuth();
      await _initializeFirestore();

      _initialized = true;
      
      if (kDebugMode) {
        print('✅ Firebase initialized successfully');
        print('📱 Project: ${DefaultFirebaseOptions.currentPlatform.projectId}');
        print('🌍 Environment: ${EnvironmentService.isProduction ? "Production" : "Development"}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Initialize Firebase Authentication
  Future<void> _initializeAuth() async {
    try {
      _auth = FirebaseAuth.instance;
      
      // Configure authentication settings
      await _auth!.setSettings(
        appVerificationDisabledForTesting: kDebugMode && !EnvironmentService.isProduction,
        forceRecaptchaFlow: EnvironmentService.isProduction,
      );

      // Set persistence for web
      if (kIsWeb) {
        await _auth!.setPersistence(Persistence.LOCAL);
      }

      if (kDebugMode) {
        print('🔐 Firebase Auth initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Initialize Firestore with production settings
  Future<void> _initializeFirestore() async {
    try {
      _firestore = FirebaseFirestore.instance;

      // Configure Firestore settings
      if (!_firestoreConfigured) {
        _firestore!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        _firestoreConfigured = true;
      }

      // Configure network settings for development
      if (kDebugMode && !EnvironmentService.isProduction) {
        await _firestore!.enableNetwork();
      }

      if (kDebugMode) {
        print('📊 Firestore initialized');
      }
    } catch (e) {
      // Settings may fail if already configured, which is okay
      if (kDebugMode) {
        print('⚠️  Firestore initialization warning: $e');
      }
    }
  }

  /// Getters for Firebase service instances
  FirebaseApp get app {
    _checkInitialization();
    return _app!;
  }

  FirebaseAuth get auth {
    _checkInitialization();
    return _auth!;
  }

  FirebaseFirestore get firestore {
    _checkInitialization();
    return _firestore!;
  }

  /// Check if Firebase is properly initialized
  void _checkInitialization() {
    if (!_initialized) {
      throw StateError('Firebase must be initialized before accessing services. Call FirebaseService.instance.initialize() first.');
    }
  }

  /// Get current user
  User? get currentUser => auth.currentUser;

  /// Check authentication state
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// FIRESTORE HELPERS

  /// Enable Firestore offline mode
  Future<void> enableFirestoreOffline() async {
    try {
      await firestore.disableNetwork();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Failed to enable offline mode: $e');
      }
    }
  }

  /// Enable Firestore online mode
  Future<void> enableFirestoreOnline() async {
    try {
      await firestore.enableNetwork();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Failed to enable online mode: $e');
      }
    }
  }

  /// Clear Firestore cache
  Future<void> clearFirestoreCache() async {
    try {
      await firestore.clearPersistence();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Failed to clear Firestore cache: $e');
      }
    }
  }

  /// AUTHENTICATION HELPERS

  /// Sign out and clear all data
  Future<void> signOutCompletely() async {
    try {
      await auth.signOut();
      await clearFirestoreCache();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Complete sign out failed: $e');
      }
    }
  }

  /// DEVELOPMENT HELPERS

  /// Connect to Firebase Emulator Suite (development only)
  Future<void> connectToEmulator({
    String host = 'localhost',
    int authPort = 9099,
    int firestorePort = 8080,
  }) async {
    if (EnvironmentService.isProduction) {
      throw StateError('Emulator connection not allowed in production');
    }

    try {
      // Connect Auth emulator
      await auth.useAuthEmulator(host, authPort);
      
      // Connect Firestore emulator
      firestore.useFirestoreEmulator(host, firestorePort);
      
      if (kDebugMode) {
        print('🧪 Connected to Firebase Emulator Suite');
        print('   Auth: $host:$authPort');
        print('   Firestore: $host:$firestorePort');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Emulator connection failed: $e');
      }
    }
  }

  /// Get Firebase project info
  Map<String, String> get projectInfo => {
    'projectId': DefaultFirebaseOptions.currentPlatform.projectId,
    'appId': DefaultFirebaseOptions.currentPlatform.appId,
    'messagingSenderId': DefaultFirebaseOptions.currentPlatform.messagingSenderId,
    'storageBucket': DefaultFirebaseOptions.currentPlatform.storageBucket ?? 'N/A',
  };

  /// Check if running in production
  bool get isProduction => FirebaseConfig.isProduction;

  /// Dispose and cleanup
  Future<void> dispose() async {
    _initialized = false;
    _app = null;
    _auth = null;
    _firestore = null;
  }

  /// LOGGING HELPERS (Simplified - for development)
  
  /// Log events to console in debug mode
  void logEvent(String name, [Map<String, Object?>? parameters]) {
    if (kDebugMode) {
      print('📊 Event: $name ${parameters ?? ''}');
    }
  }

  /// Log screen view to console in debug mode
  void logScreenView(String screenName, [String? screenClass]) {
    if (kDebugMode) {
      print('📱 Screen: $screenName ${screenClass ?? ''}');
    }
  }

  /// Log login event
  void logLogin(String method, {String? role}) {
    logEvent('login', {
      'method': method,
      if (role != null) 'user_role': role,
    });
  }

  /// Log signup event
  void logSignup(String method, {String? role}) {
    logEvent('sign_up', {
      'method': method,
      if (role != null) 'user_role': role,
    });
  }

  /// Record error to console in debug mode
  void recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, String>? context,
  }) {
    if (kDebugMode) {
      print('❌ Error${fatal ? ' (FATAL)' : ''}: $exception');
      if (context != null) {
        print('   Context: $context');
      }
      if (stackTrace != null) {
        print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}...');
      }
    }
  }

  /// Set user information for logging
  void setUserInfo({
    required String userId,
    String? email,
    String? role,
  }) {
    if (kDebugMode) {
      print('👤 User: $userId, Email: $email, Role: $role');
    }
  }
}

/// Global Firebase service instance for easy access
final firebaseService = FirebaseService.instance;