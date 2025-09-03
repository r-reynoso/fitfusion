import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DemoAuthService {
  static const String _usersKey = 'demo_users';
  static const String _currentUserKey = 'demo_current_user';
  static const String _clientsKey = 'demo_clients';
  
  // No more pre-defined demo trainers - only real user accounts allowed

  Future<String?> registerTrainer({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? specialization,
    int? experienceYears,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Get existing users
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      
      // Check if email already exists
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['email'] == email) {
          return 'An account with this email already exists. Please use a different email or sign in instead.';
        }
      }
      
      // Create new trainer
      String userId = 'trainer_${DateTime.now().millisecondsSinceEpoch}';
      UserData newTrainer = UserData(
        id: userId,
        email: email,
        role: UserRole.trainer,
        name: name,
        phone: phone,
        specialization: specialization,
        experienceYears: experienceYears,
      );
      
      // Add to users list
      Map<String, dynamic> userMap = newTrainer.toFirestore();
      userMap['id'] = userId;
      userMap['password'] = password; // Store password for demo only
      
      usersList.add(json.encode(userMap));
      await prefs.setStringList(_usersKey, usersList);
      
      return null; // Success
    } catch (e) {
      return 'Registration failed. Please try again.';
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Get existing users
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      
      // Check if email already exists
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['email'] == email) {
          return 'An account with this email already exists. Please use a different email or sign in instead.';
        }
      }
      
      // Create new client
      String userId = 'client_${DateTime.now().millisecondsSinceEpoch}';
      UserData newClient = UserData(
        id: userId,
        email: email,
        role: UserRole.client,
        name: name,
        phone: phone,
        trainerId: trainerId,
      );
      
      // Add to users list
      Map<String, dynamic> userMap = newClient.toFirestore();
      userMap['id'] = userId;
      userMap['password'] = password; // Store password for demo only
      
      usersList.add(json.encode(userMap));
      await prefs.setStringList(_usersKey, usersList);
      
      // Store client metrics
      List<String> clientsList = prefs.getStringList(_clientsKey) ?? [];
      ClientMetrics metrics = ClientMetrics(
        weight: weight,
        height: height,
        age: age,
        goals: goals,
        gender: gender,
      );
      
      Map<String, dynamic> clientData = {
        'userId': userId,
        'trainerId': trainerId,
        'metrics': metrics.toFirestore(),
      };
      
      clientsList.add(json.encode(clientData));
      await prefs.setStringList(_clientsKey, clientsList);
      
      return null; // Success
    } catch (e) {
      return 'Registration failed. Please try again.';
    }
  }

  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
    bool rememberMe,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Get existing users
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      
      // Find user by email and password
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['email'] == email && userData['password'] == password) {
          // Store current user
          await prefs.setString(_currentUserKey, userStr);
          
          if (rememberMe) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('user_email', email);
          }
          
          return null; // Success
        }
      }
      
      return 'Invalid email or password. Please try again.';
    } catch (e) {
      return 'Sign in failed. Please try again.';
    }
  }

  Future<UserData?> getCurrentUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentUserStr = prefs.getString(_currentUserKey);
      
      if (currentUserStr != null) {
        Map<String, dynamic> userData = json.decode(currentUserStr);
        return UserData(
          id: userData['id'],
          email: userData['email'],
          role: userData['role'] == 'trainer' ? UserRole.trainer : UserRole.client,
          name: userData['name'],
          phone: userData['phone'],
          specialization: userData['specialization'],
          experienceYears: userData['experienceYears'],
          trainerId: userData['trainerId'],
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ClientMetrics?> getClientMetrics(String clientId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // First check current user data if this is the current client
      String? currentUserJson = prefs.getString(_currentUserKey);
      if (currentUserJson != null) {
        Map<String, dynamic> currentUser = json.decode(currentUserJson);
        if (currentUser['id'] == clientId && currentUser['role'] == 'client') {
          if (currentUser['metrics'] != null) {
            return ClientMetrics.fromFirestore(currentUser['metrics']);
          }
        }
      }
      
      // Check users list for client data
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['id'] == clientId && userData['role'] == 'client') {
          if (userData['metrics'] != null) {
            return ClientMetrics.fromFirestore(userData['metrics']);
          }
        }
      }
      
      // Check clients list for client data
      List<String> clientsList = prefs.getStringList(_clientsKey) ?? [];
      for (String clientStr in clientsList) {
        Map<String, dynamic> clientData = json.decode(clientStr);
        if (clientData['userId'] == clientId || clientData['id'] == clientId) {
          return ClientMetrics.fromFirestore(clientData['metrics']);
        }
      }
      
      // Return demo metrics if client not found
      return _getDemoClientMetrics(clientId);
    } catch (e) {
      return _getDemoClientMetrics(clientId);
    }
  }

  ClientMetrics? _getDemoClientMetrics(String clientId) {
    // No demo client metrics - return null
    return null;
  }

  Future<List<UserData>> getTrainers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      
      List<UserData> trainers = [];
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['role'] == 'trainer') {
          trainers.add(UserData(
            id: userData['id'],
            email: userData['email'],
            role: UserRole.trainer,
            name: userData['name'],
            phone: userData['phone'],
            specialization: userData['specialization'],
            experienceYears: userData['experienceYears'],
          ));
        }
      }
      
      return trainers;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrainerClients(String trainerId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Get all users and client metrics
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      List<String> clientsList = prefs.getStringList(_clientsKey) ?? [];
      
      List<Map<String, dynamic>> trainerClients = [];
      
      // Find all clients associated with this trainer
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        
        // Check if this is a client and belongs to this trainer
        if (userData['role'] == 'client' && userData['trainerId'] == trainerId) {
          // Get the client's metrics - first check user data itself
          Map<String, dynamic>? clientMetrics = userData['metrics'];
          
          // If not found in user data, check clients list
          if (clientMetrics == null) {
            for (String clientStr in clientsList) {
              Map<String, dynamic> clientData = json.decode(clientStr);
              if ((clientData['userId'] == userData['id'] || clientData['id'] == userData['id']) && 
                  clientData['trainerId'] == trainerId) {
                clientMetrics = clientData['metrics'];
                break;
              }
            }
          }
          
          // Add client to the list
          trainerClients.add({
            'id': userData['id'],
            'userId': userData['id'],
            'name': userData['name'],
            'email': userData['email'],
            'phone': userData['phone'],
            'metrics': clientMetrics ?? {
              'weight': 0.0,
              'height': 0.0,
              'age': 0,
              'goals': null
            },
          });
        }
      }
      
      // Return only real clients - no demo clients
      
      return trainerClients;
    } catch (e) {
      print('Error getting trainer clients: $e');
      return [];
    }
  }

  Future<String?> getClientNameById(String clientId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      
      // Search in stored users first
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['id'] == clientId && userData['role'] == 'client') {
          return userData['name'];
        }
      }
      
      // No demo client fallbacks - return null if not found
      return null;
    } catch (e) {
      print('Error getting client name: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove('remember_me');
    await prefs.remove('user_email');
  }

  bool isSignedIn() {
    return false; // For demo mode, always return false for authStateChanges
  }

  Stream<UserData?> get authStateChanges {
    return Stream.fromFuture(getCurrentUserData());
  }

  Future<UserData?> getTrainerById(String trainerId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> trainersJson = prefs.getStringList('demo_trainers') ?? [];
      
      for (String trainerJson in trainersJson) {
        Map<String, dynamic> trainerData = Map<String, dynamic>.from(json.decode(trainerJson));
        if (trainerData['id'] == trainerId) {
          return UserData(
            id: trainerData['id'],
            email: trainerData['email'],
            role: UserRole.trainer,
            name: trainerData['name'],
            phone: trainerData['phone'],
            specialization: trainerData['specialization'],
            experienceYears: trainerData['experienceYears'],
          );
        }
      }
      
      // No demo trainer fallbacks - return null if not found
      return null;
    } catch (e) {
      print('Error getting trainer by ID: $e');
      return null;
    }
  }

  Future<String?> updateClientMetrics(String clientId, {
    double? weight,
    double? height,
    int? age,
    String? goals,
    String? gender,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentUserJson = prefs.getString(_currentUserKey);
      
      if (currentUserJson != null) {
        Map<String, dynamic> currentUser = json.decode(currentUserJson);
        
        // Update metrics if this is the current client
        if (currentUser['id'] == clientId && currentUser['role'] == 'client') {
          Map<String, dynamic> metrics = Map<String, dynamic>.from(currentUser['metrics'] ?? {});
          
          if (weight != null) metrics['weight'] = weight;
          if (height != null) metrics['height'] = height;
          if (age != null) metrics['age'] = age;
          if (goals != null) metrics['goals'] = goals;
          if (gender != null) metrics['gender'] = gender;
          metrics['updatedAt'] = DateTime.now().toIso8601String();
          
          currentUser['metrics'] = metrics;
          await prefs.setString(_currentUserKey, json.encode(currentUser));
          
          // Also update in the stored clients list if exists
          List<String> clientsJson = prefs.getStringList('demo_clients') ?? [];
          List<String> updatedClients = [];
          
          for (String clientJson in clientsJson) {
            Map<String, dynamic> client = Map<String, dynamic>.from(json.decode(clientJson));
            if (client['id'] == clientId) {
              client['metrics'] = metrics;
            }
            updatedClients.add(json.encode(client));
          }
          
          await prefs.setStringList('demo_clients', updatedClients);
        }
      }
      
      return null; // Success
    } catch (e) {
      print('Error updating client metrics: $e');
      return 'Failed to update metrics: $e';
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Update current user data
      String? currentUserJson = prefs.getString(_currentUserKey);
      if (currentUserJson != null) {
        Map<String, dynamic> currentUser = json.decode(currentUserJson);
        
        if (currentUser['id'] == clientId && currentUser['role'] == 'client') {
          // Update user profile fields
          if (name != null) currentUser['name'] = name;
          if (email != null) currentUser['email'] = email;
          if (phone != null) currentUser['phone'] = phone;
          
          // Update metrics
          Map<String, dynamic> metrics = Map<String, dynamic>.from(currentUser['metrics'] ?? {});
          if (weight != null) metrics['weight'] = weight;
          if (height != null) metrics['height'] = height;
          if (age != null) metrics['age'] = age;
          if (goals != null) metrics['goals'] = goals;
          if (gender != null) metrics['gender'] = gender;
          metrics['updatedAt'] = DateTime.now().toIso8601String();
          
          currentUser['metrics'] = metrics;
          currentUser['updatedAt'] = DateTime.now().toIso8601String();
          
          await prefs.setString(_currentUserKey, json.encode(currentUser));
        }
      }
      
      // Update in users list
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      List<String> updatedUsers = [];
      
      for (String userStr in usersList) {
        Map<String, dynamic> userData = json.decode(userStr);
        if (userData['id'] == clientId && userData['role'] == 'client') {
          // Update user profile fields
          if (name != null) userData['name'] = name;
          if (email != null) userData['email'] = email;
          if (phone != null) userData['phone'] = phone;
          
          // Update metrics if available
          if (weight != null || height != null || age != null || goals != null || gender != null) {
            Map<String, dynamic> metrics = Map<String, dynamic>.from(userData['metrics'] ?? {});
            if (weight != null) metrics['weight'] = weight;
            if (height != null) metrics['height'] = height;
            if (age != null) metrics['age'] = age;
            if (goals != null) metrics['goals'] = goals;
            if (gender != null) metrics['gender'] = gender;
            metrics['updatedAt'] = DateTime.now().toIso8601String();
            userData['metrics'] = metrics;
          }
          
          userData['updatedAt'] = DateTime.now().toIso8601String();
        }
        updatedUsers.add(json.encode(userData));
      }
      
      await prefs.setStringList(_usersKey, updatedUsers);
      
      // Update in clients list if exists
      List<String> clientsJson = prefs.getStringList(_clientsKey) ?? [];
      List<String> updatedClients = [];
      
      for (String clientJson in clientsJson) {
        Map<String, dynamic> client = Map<String, dynamic>.from(json.decode(clientJson));
        if (client['id'] == clientId || client['userId'] == clientId) {
          // Update client info
          if (name != null) client['name'] = name;
          if (email != null) client['email'] = email;
          if (phone != null) client['phone'] = phone;
          
          if (weight != null || height != null || age != null || goals != null || gender != null) {
            Map<String, dynamic> metrics = Map<String, dynamic>.from(client['metrics'] ?? {});
            if (weight != null) metrics['weight'] = weight;
            if (height != null) metrics['height'] = height;
            if (age != null) metrics['age'] = age;
            if (goals != null) metrics['goals'] = goals;
            if (gender != null) metrics['gender'] = gender;
            metrics['updatedAt'] = DateTime.now().toIso8601String();
            client['metrics'] = metrics;
          }
          
          client['updatedAt'] = DateTime.now().toIso8601String();
        }
        updatedClients.add(json.encode(client));
      }
      
      await prefs.setStringList(_clientsKey, updatedClients);
      
      return null; // Success
    } catch (e) {
      print('Error updating client info: $e');
      return 'Failed to update information: $e';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    // For demo mode, just return success
    return null;
  }

  Future<String?> deleteClient(String clientId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Remove from users list
      List<String> usersList = prefs.getStringList(_usersKey) ?? [];
      usersList.removeWhere((userStr) {
        Map<String, dynamic> userData = json.decode(userStr);
        return userData['id'] == clientId;
      });
      await prefs.setStringList(_usersKey, usersList);
      
      // Remove from clients list
      List<String> clientsList = prefs.getStringList(_clientsKey) ?? [];
      clientsList.removeWhere((clientStr) {
        Map<String, dynamic> clientData = json.decode(clientStr);
        return clientData['userId'] == clientId || clientData['id'] == clientId;
      });
      await prefs.setStringList(_clientsKey, clientsList);
      
      return null; // Success
    } catch (e) {
      print('Error deleting client: $e');
      return 'Failed to delete client. Please try again.';
    }
  }
}