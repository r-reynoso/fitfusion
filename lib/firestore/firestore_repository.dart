import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/routine_service.dart';
import 'firestore_data_schema.dart';

/// Repository pattern implementation for Firestore operations
/// This class demonstrates Firebase best practices and provides
/// a clean abstraction layer over Firestore operations.
class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references with type safety
  CollectionReference<Map<String, dynamic>> get _users => 
      _firestore.collection(FirestoreDataSchema.usersCollection);
  
  CollectionReference<Map<String, dynamic>> get _clients => 
      _firestore.collection(FirestoreDataSchema.clientsCollection);
      
  CollectionReference<Map<String, dynamic>> get _routines => 
      _firestore.collection(FirestoreDataSchema.routinesCollection);

  /// USER OPERATIONS
  
  /// Create a new user document
  Future<void> createUser(UserData userData) async {
    try {
      await _users.doc(userData.id).set(userData.toFirestore());
    } catch (e) {
      throw FirestoreException('Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<UserData?> getUser(String userId) async {
    try {
      DocumentSnapshot doc = await _users.doc(userId).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user: $e');
    }
  }

  /// Get all trainers (paginated)
  Future<List<UserData>> getTrainers({
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _users
          .where('role', isEqualTo: 'trainer')
          .orderBy('name')
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserData.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to get trainers: $e');
    }
  }

  /// Update user data
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FirestoreHelper.serverTimestamp;
      await _users.doc(userId).update(updates);
    } catch (e) {
      throw FirestoreException('Failed to update user: $e');
    }
  }

  /// Delete user (requires admin privileges)
  Future<void> deleteUser(String userId) async {
    try {
      await FirestoreHelper.runTransaction((transaction) async {
        // Delete user document
        DocumentReference userRef = _users.doc(userId);
        transaction.delete(userRef);

        // Delete client document if exists
        DocumentReference clientRef = _clients.doc(userId);
        transaction.delete(clientRef);

        // Note: Routines should be handled by Cloud Function cascade delete
      });
    } catch (e) {
      throw FirestoreException('Failed to delete user: $e');
    }
  }

  /// CLIENT OPERATIONS

  /// Create client with metrics
  Future<void> createClient({
    required String clientId,
    required String trainerId,
    required ClientMetrics metrics,
  }) async {
    try {
      await _clients.doc(clientId).set({
        'userId': clientId,
        'trainerId': trainerId,
        'metrics': metrics.toFirestore(),
        'createdAt': FirestoreHelper.serverTimestamp,
        'updatedAt': FirestoreHelper.serverTimestamp,
      });
    } catch (e) {
      throw FirestoreException('Failed to create client: $e');
    }
  }

  /// Get trainer's clients with user info
  Future<List<Map<String, dynamic>>> getTrainerClients(
    String trainerId, {
    int limit = 50,
  }) async {
    try {
      // Get clients for this trainer
      QuerySnapshot clientSnapshot = await _clients
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> clients = [];
      
      // Use batch to get all user data efficiently
      List<Future<DocumentSnapshot>> userFutures = clientSnapshot.docs
          .map((doc) => _users.doc(doc.id).get())
          .toList();

      List<DocumentSnapshot> userDocs = await Future.wait(userFutures);

      for (int i = 0; i < clientSnapshot.docs.length; i++) {
        Map<String, dynamic> clientData = 
            clientSnapshot.docs[i].data() as Map<String, dynamic>;
        
        if (userDocs[i].exists) {
          Map<String, dynamic> userData = 
              userDocs[i].data() as Map<String, dynamic>;
          
          clients.add({
            'id': clientSnapshot.docs[i].id,
            'userId': clientData['userId'],
            'name': userData['name'] ?? 'Unknown',
            'email': userData['email'] ?? '',
            'phone': userData['phone'],
            'metrics': clientData['metrics'] ?? {},
            'createdAt': clientData['createdAt'],
            'updatedAt': clientData['updatedAt'],
          });
        }
      }

      // Sort by name
      clients.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      return clients;
    } catch (e) {
      throw FirestoreException('Failed to get trainer clients: $e');
    }
  }

  /// Update client metrics
  Future<void> updateClientMetrics(
    String clientId,
    ClientMetrics metrics,
  ) async {
    try {
      await _clients.doc(clientId).update({
        'metrics': metrics.toFirestore(),
        'updatedAt': FirestoreHelper.serverTimestamp,
      });
    } catch (e) {
      throw FirestoreException('Failed to update client metrics: $e');
    }
  }

  /// Get client metrics
  Future<ClientMetrics?> getClientMetrics(String clientId) async {
    try {
      DocumentSnapshot doc = await _clients.doc(clientId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic>? metricsData = data['metrics'];
        
        if (metricsData != null) {
          return ClientMetrics.fromFirestore(metricsData);
        }
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get client metrics: $e');
    }
  }

  /// ROUTINE OPERATIONS

  /// Create workout routine
  Future<String> createRoutine(WorkoutRoutine routine) async {
    try {
      DocumentReference docRef = await _routines.add({
        ...routine.toFirestore(),
        'createdAt': FirestoreHelper.serverTimestamp,
      });
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to create routine: $e');
    }
  }

  /// Get routine by ID
  Future<WorkoutRoutine?> getRoutine(String routineId) async {
    try {
      DocumentSnapshot doc = await _routines.doc(routineId).get();
      if (doc.exists) {
        return WorkoutRoutine.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get routine: $e');
    }
  }

  /// Get trainer's routines (paginated with real-time updates)
  Stream<List<WorkoutRoutine>> getTrainerRoutinesStream(
    String trainerId, {
    int limit = 25,
  }) {
    return _routines
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutRoutine.fromFirestore(doc))
            .toList());
  }

  /// Get client's routines (paginated)
  Future<List<WorkoutRoutine>> getClientRoutines(
    String clientId, {
    int limit = 25,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _routines
          .where('clientId', isEqualTo: clientId)
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => WorkoutRoutine.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to get client routines: $e');
    }
  }

  /// Update routine
  Future<void> updateRoutine(String routineId, WorkoutRoutine routine) async {
    try {
      await _routines.doc(routineId).update(routine.toFirestore());
    } catch (e) {
      throw FirestoreException('Failed to update routine: $e');
    }
  }

  /// Delete routine
  Future<void> deleteRoutine(String routineId) async {
    try {
      await _routines.doc(routineId).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete routine: $e');
    }
  }

  /// Generate public token for routine sharing
  Future<String> generatePublicToken(
    String routineId,
    DateTime? expiresAt,
  ) async {
    try {
      return await FirestoreHelper.runTransaction<String>((transaction) async {
        DocumentReference routineRef = _routines.doc(routineId);
        DocumentSnapshot routineSnapshot = await transaction.get(routineRef);
        
        if (!routineSnapshot.exists) {
          throw FirestoreException('Routine not found');
        }
        
        // Generate secure token (same logic as in RoutineService)
        String token = _generateSecureToken(routineId);
        
        transaction.update(routineRef, {
          'isPublic': true,
          'publicToken': token,
          'publicExpiresAt': expiresAt,
          'updatedAt': FirestoreHelper.serverTimestamp,
        });
        
        return token;
      });
    } catch (e) {
      throw FirestoreException('Failed to generate public token: $e');
    }
  }

  /// Get routine by public token
  Future<WorkoutRoutine?> getRoutineByPublicToken(String token) async {
    try {
      QuerySnapshot snapshot = await _routines
          .where('publicToken', isEqualTo: token)
          .where('isPublic', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        WorkoutRoutine routine = WorkoutRoutine.fromFirestore(snapshot.docs.first);
        
        // Check expiration
        if (routine.publicExpiresAt != null && 
            routine.publicExpiresAt!.isBefore(DateTime.now())) {
          return null; // Token expired
        }
        
        return routine;
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get routine by token: $e');
    }
  }

  /// Search routines by title (limited Firestore text search)
  Future<List<WorkoutRoutine>> searchRoutines(
    String query, {
    int limit = 20,
  }) async {
    try {
      QuerySnapshot snapshot = await _routines
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .orderBy('title')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => WorkoutRoutine.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to search routines: $e');
    }
  }

  /// AGGREGATE OPERATIONS

  /// Get routine statistics
  Future<Map<String, int>> getRoutineStats() async {
    try {
      // Use aggregate queries for better performance
      AggregateQuerySnapshot totalCount = await _routines.count().get();
      
      AggregateQuerySnapshot publicCount = await _routines
          .where('isPublic', isEqualTo: true)
          .count()
          .get();

      int total = totalCount.count ?? 0;
      int publicRoutines = publicCount.count ?? 0;
      
      return {
        'totalRoutines': total,
        'publicRoutines': publicRoutines,
        'privateRoutines': total - publicRoutines,
      };
    } catch (e) {
      // Fallback to document count if aggregate queries fail
      try {
        QuerySnapshot allRoutines = await _routines.get();
        QuerySnapshot publicRoutines = await _routines
            .where('isPublic', isEqualTo: true)
            .get();

        int total = allRoutines.docs.length;
        int publicCount = publicRoutines.docs.length;
        
        return {
          'totalRoutines': total,
          'publicRoutines': publicCount,
          'privateRoutines': total - publicCount,
        };
      } catch (fallbackError) {
        throw FirestoreException('Failed to get routine stats: $fallbackError');
      }
    }
  }

  /// Get trainer statistics
  Future<Map<String, int>> getTrainerStats(String trainerId) async {
    try {
      AggregateQuerySnapshot clientCount = await _clients
          .where('trainerId', isEqualTo: trainerId)
          .count()
          .get();

      AggregateQuerySnapshot routineCount = await _routines
          .where('trainerId', isEqualTo: trainerId)
          .count()
          .get();

      return {
        'totalClients': clientCount.count ?? 0,
        'totalRoutines': routineCount.count ?? 0,
      };
    } catch (e) {
      throw FirestoreException('Failed to get trainer stats: $e');
    }
  }

  /// BATCH OPERATIONS

  /// Delete all data for a client (cascading delete)
  Future<void> deleteClientData(String clientId) async {
    try {
      WriteBatch batch = FirestoreHelper.batch();
      
      // Delete user document
      batch.delete(_users.doc(clientId));
      
      // Delete client document
      batch.delete(_clients.doc(clientId));
      
      // Get all routines for this client
      QuerySnapshot routines = await _routines
          .where('clientId', isEqualTo: clientId)
          .get();
      
      // Add routine deletions to batch
      for (QueryDocumentSnapshot doc in routines.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw FirestoreException('Failed to delete client data: $e');
    }
  }

  /// Bulk update routine visibility
  Future<void> bulkUpdateRoutineVisibility(
    List<String> routineIds,
    bool isPublic,
  ) async {
    try {
      WriteBatch batch = FirestoreHelper.batch();
      
      for (String routineId in routineIds) {
        DocumentReference ref = _routines.doc(routineId);
        batch.update(ref, {
          'isPublic': isPublic,
          'updatedAt': FirestoreHelper.serverTimestamp,
          // Remove public token if making private
          if (!isPublic) ...{
            'publicToken': FirestoreHelper.deleteField,
            'publicExpiresAt': FirestoreHelper.deleteField,
          }
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw FirestoreException('Failed to bulk update routine visibility: $e');
    }
  }

  /// UTILITY METHODS

  /// Generate secure token for public sharing
  String _generateSecureToken(String routineId) {
    // Implementation from RoutineService
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String randomStr = DateTime.now().microsecond.toString().padLeft(6, '0');
    return '$routineId-$timestamp-$randomStr'.hashCode.abs().toString();
  }

  /// Check if user has permission to access resource
  Future<bool> checkUserPermission(
    String userId,
    String resourceType,
    String resourceId,
  ) async {
    try {
      switch (resourceType) {
        case 'routine':
          DocumentSnapshot routineDoc = await _routines.doc(resourceId).get();
          if (!routineDoc.exists) return false;
          
          Map<String, dynamic> data = routineDoc.data() as Map<String, dynamic>;
          return data['trainerId'] == userId || 
                 data['clientId'] == userId ||
                 data['isPublic'] == true;
                 
        case 'client':
          DocumentSnapshot clientDoc = await _clients.doc(resourceId).get();
          if (!clientDoc.exists) return false;
          
          Map<String, dynamic> data = clientDoc.data() as Map<String, dynamic>;
          return data['trainerId'] == userId || data['userId'] == userId;
          
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }
}

/// Custom exception for Firestore operations
class FirestoreException implements Exception {
  final String message;
  
  FirestoreException(this.message);
  
  @override
  String toString() => 'FirestoreException: $message';
}

/// Repository singleton instance
final firestoreRepository = FirestoreRepository();