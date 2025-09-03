import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'environment_service.dart';

enum UserRole { trainer, client }

class UserData {
  final String id;
  final String email;
  final UserRole role;
  final String name;
  final String? phone;
  final String? specialization;
  final int? experienceYears;
  final String? trainerId;

  UserData({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.specialization,
    this.experienceYears,
    this.trainerId,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserData(
      id: doc.id,
      email: data['email'] ?? '',
      role: data['role'] == 'trainer' ? UserRole.trainer : UserRole.client,
      name: data['name'] ?? '',
      phone: data['phone'],
      specialization: data['specialization'],
      experienceYears: data['experienceYears'],
      trainerId: data['trainerId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role == UserRole.trainer ? 'trainer' : 'client',
      'name': name,
      'phone': phone,
      'specialization': specialization,
      'experienceYears': experienceYears,
      'trainerId': trainerId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ClientMetrics {
  final double weight;
  final double height;
  final int age;
  final String? goals;
  final String? gender;

  ClientMetrics({
    required this.weight,
    required this.height,
    required this.age,
    this.goals,
    this.gender,
  });

  factory ClientMetrics.fromFirestore(Map<String, dynamic> data) {
    return ClientMetrics(
      weight: (data['weight'] ?? 0).toDouble(),
      height: (data['height'] ?? 0).toDouble(),
      age: data['age'] ?? 0,
      goals: data['goals'],
      gender: data['gender'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weight': weight,
      'height': height,
      'age': age,
      'goals': goals,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if we're in production mode
  bool get _isProduction => EnvironmentService.isProduction;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserData?> getCurrentUserData() async {
    if (currentUser == null) return null;
    
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<ClientMetrics?> getClientMetrics(String clientId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('clients')
          .doc(clientId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic>? metricsData = data['metrics'];
        
        if (metricsData != null) {
          return ClientMetrics.fromFirestore(metricsData);
        }
      }
      return null;
    } catch (e) {
      print('Error getting client metrics: $e');
      return null;
    }
  }

  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
    bool rememberMe,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set persistence based on rememberMe
      if (rememberMe) {
        await _auth.setPersistence(Persistence.LOCAL);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', true);
        await prefs.setString('user_email', email);
      } else {
        await _auth.setPersistence(Persistence.SESSION);
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      // Enhanced error messages for production
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email address. Please register first or check your email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again or use "Forgot Password" to reset it.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support at support@fitfusion.app.';
        case 'too-many-requests':
          return 'Too many sign-in attempts. Please wait 15 minutes before trying again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'invalid-credential':
          return 'Invalid email or password. Please check your credentials and try again.';
        default:
          return e.message ?? 'Sign in failed. Please try again or contact support.';
      }
    } catch (e) {
      print('Unexpected error during sign in: $e');
      return 'An unexpected error occurred during sign in. Please try again.';
    }
  }

  Future<String?> registerTrainer({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? specialization,
    int? experienceYears,
  }) async {
    try {
      // Validate input
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }
      if (!_isValidPassword(password)) {
        return 'Password must be at least 8 characters long and contain uppercase, lowercase, number, and special character.';
      }
      if (name.trim().isEmpty) {
        return 'Please enter your full name.';
      }

      print('Registering trainer with email: $email');
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('User created successfully with UID: ${result.user!.uid}');

      // Send email verification
      await result.user!.sendEmailVerification();

      UserData userData = UserData(
        id: result.user!.uid,
        email: email.trim().toLowerCase(),
        role: UserRole.trainer,
        name: name.trim(),
        phone: phone?.trim(),
        specialization: specialization?.trim(),
        experienceYears: experienceYears,
      );

      await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .set(userData.toFirestore());

      print('Trainer data saved to Firestore successfully');
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists. Please use a different email or sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 8 characters with uppercase, lowercase, numbers, and special characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'too-many-requests':
          return 'Too many registration attempts. Please wait a few minutes before trying again.';
        case 'operation-not-allowed':
          return 'Registration is temporarily disabled. Please contact support.';
        default:
          return e.message ?? 'Registration failed. Please try again.';
      }
    } catch (e) {
      print('Unexpected error during trainer registration: $e');
      return 'Registration failed. Please check your information and try again.';
    }
  }

  Future<String?> registerClient({
    required String email,
    required String password,
    required String name,
    required String trainerId,
    required double weight,
    required double height,
    required int age,
    String? phone,
    String? goals,
    String? gender,
  }) async {
    try {
      // Validate input
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }
      if (!_isValidPassword(password)) {
        return 'Password must be at least 8 characters long and contain uppercase, lowercase, number, and special character.';
      }
      if (name.trim().isEmpty) {
        return 'Please enter your full name.';
      }
      if (weight <= 0 || height <= 0 || age <= 0) {
        return 'Please enter valid weight, height, and age.';
      }

      // Verify trainer exists
      DocumentSnapshot trainerDoc = await _firestore
          .collection('users')
          .doc(trainerId)
          .get();
      
      if (!trainerDoc.exists) {
        return 'Selected trainer not found. Please choose a different trainer.';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Send email verification
      await result.user!.sendEmailVerification();

      UserData userData = UserData(
        id: result.user!.uid,
        email: email.trim().toLowerCase(),
        role: UserRole.client,
        name: name.trim(),
        phone: phone?.trim(),
        trainerId: trainerId,
      );

      // Use batch write for consistency
      WriteBatch batch = _firestore.batch();

      // Create user document
      DocumentReference userRef = _firestore.collection('users').doc(result.user!.uid);
      batch.set(userRef, userData.toFirestore());

      // Create client document with metrics
      ClientMetrics metrics = ClientMetrics(
        weight: weight,
        height: height,
        age: age,
        goals: goals?.trim(),
        gender: gender,
      );

      DocumentReference clientRef = _firestore.collection('clients').doc(result.user!.uid);
      batch.set(clientRef, {
        'userId': result.user!.uid,
        'trainerId': trainerId,
        'metrics': metrics.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists. Please use a different email or sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 8 characters with uppercase, lowercase, numbers, and special characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'too-many-requests':
          return 'Too many registration attempts. Please wait a few minutes before trying again.';
        case 'operation-not-allowed':
          return 'Registration is temporarily disabled. Please contact support.';
        default:
          return e.message ?? 'Registration failed. Please try again.';
      }
    } catch (e) {
      print('Unexpected error during client registration: $e');
      return 'Registration failed. Please check your information and try again.';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }

      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email address. Please check your email or register first.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'too-many-requests':
          return 'Too many password reset requests. Please wait before trying again.';
        default:
          return e.message ?? 'Failed to send password reset email. Please try again.';
      }
    } catch (e) {
      print('Error sending password reset email: $e');
      return 'Failed to send password reset email. Please try again.';
    }
  }

  Future<List<UserData>> getTrainers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => UserData.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting trainers: $e');
      return [];
    }
  }

  Future<void> signOut() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me');
      await prefs.remove('user_email');
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      // Continue with sign out even if preferences fail
      await _auth.signOut();
    }
  }

  Future<bool> checkRememberMe() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('remember_me') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTrainerClients(String trainerId) async {
    try {
      QuerySnapshot clientsSnapshot = await _firestore
          .collection('clients')
          .where('trainerId', isEqualTo: trainerId)
          .get();

      List<Map<String, dynamic>> clients = [];
      for (var clientDoc in clientsSnapshot.docs) {
        Map<String, dynamic> clientData = clientDoc.data() as Map<String, dynamic>;
        
        // Get user data for this client
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(clientData['userId'])
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          clients.add({
            'id': clientDoc.id,
            'userId': clientData['userId'],
            'name': userData['name'] ?? 'Unknown',
            'email': userData['email'] ?? '',
            'phone': userData['phone'],
            'metrics': clientData['metrics'] ?? {},
          });
        }
      }
      
      // Sort clients by name
      clients.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      return clients;
    } catch (e) {
      print('Error getting trainer clients: $e');
      return [];
    }
  }

  Future<UserData?> getTrainerById(String trainerId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(trainerId)
          .get();

      if (userDoc.exists) {
        return UserData.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      print('Error getting trainer by ID: $e');
      return null;
    }
  }

  Future<String?> updateClientInfo(String clientId, {
    String? name,
    String? email,
    String? phone,
    double? weight,
    double? height,
    int? age,
    String? goals,
    String? gender,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      Map<String, dynamic> userUpdates = {};
      Map<String, dynamic> metricsUpdates = {};
      
      // User profile updates
      if (name != null) userUpdates['name'] = name.trim();
      if (email != null) userUpdates['email'] = email.trim().toLowerCase();
      if (phone != null) userUpdates['phone'] = phone.trim();
      
      // Metrics updates
      if (weight != null) metricsUpdates['weight'] = weight;
      if (height != null) metricsUpdates['height'] = height;
      if (age != null) metricsUpdates['age'] = age;
      if (goals != null) metricsUpdates['goals'] = goals.trim();
      if (gender != null) metricsUpdates['gender'] = gender;
      
      // Update user profile
      if (userUpdates.isNotEmpty) {
        userUpdates['updatedAt'] = FieldValue.serverTimestamp();
        DocumentReference userRef = _firestore.collection('users').doc(clientId);
        batch.update(userRef, userUpdates);
      }
      
      // Update metrics
      if (metricsUpdates.isNotEmpty) {
        metricsUpdates['updatedAt'] = FieldValue.serverTimestamp();
        DocumentReference clientRef = _firestore.collection('clients').doc(clientId);
        batch.update(clientRef, {
          'metrics': metricsUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      return null; // Success
    } catch (e) {
      print('Error updating client info: $e');
      return 'Failed to update information: ${e.toString()}';
    }
  }

  Future<String?> getClientNameById(String clientId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(clientId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'];
      }
      return null;
    } catch (e) {
      print('Error getting client name: $e');
      return null;
    }
  }

  Future<String?> deleteClient(String clientId) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      // Delete the client document
      DocumentReference clientRef = _firestore.collection('clients').doc(clientId);
      batch.delete(clientRef);
      
      // Delete the user document
      DocumentReference userRef = _firestore.collection('users').doc(clientId);
      batch.delete(userRef);
      
      await batch.commit();
      
      // Note: Firebase Auth user deletion requires Cloud Function
      // This will be handled by the admin function
      
      return null; // Success
    } catch (e) {
      print('Error deleting client: $e');
      return 'Failed to delete client. Please try again.';
    }
  }

  // Helper methods
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number, 1 special character
    return password.length >= 8 &&
           RegExp(r'[A-Z]').hasMatch(password) &&
           RegExp(r'[a-z]').hasMatch(password) &&
           RegExp(r'[0-9]').hasMatch(password) &&
           RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }
}