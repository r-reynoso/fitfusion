import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/routine_service.dart';
import 'firebase_service_simplified.dart';
import 'firestore_repository.dart';
import 'firestore_data_schema.dart';

/// Simplified examples demonstrating Firebase client code usage
/// This file shows best practices for implementing Firebase operations
/// in FitFusion with proper error handling and logging
class FirebaseExamples {
  
  /// EXAMPLE 1: User Registration with Complete Error Handling
  static Future<String?> registerTrainerExample({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? specialization,
    int? experienceYears,
  }) async {
    try {
      // Log registration attempt
      firebaseService.logEvent('registration_attempt', {
        'user_type': 'trainer',
        'has_specialization': specialization != null,
        'has_experience': experienceYears != null,
      });

      // Use the existing auth service
      final authService = AuthService();
      String? error = await authService.registerTrainer(
        email: email,
        password: password,
        name: name,
        phone: phone,
        specialization: specialization,
        experienceYears: experienceYears,
      );

      if (error == null) {
        // Registration successful
        firebaseService.logSignup('email', role: 'trainer');
        
        // Set user info for logging
        if (firebaseService.currentUser != null) {
          firebaseService.setUserInfo(
            userId: firebaseService.currentUser!.uid,
            email: email,
            role: 'trainer',
          );
        }

        if (kDebugMode) {
          print('✅ Trainer registration successful');
        }
        return null; // Success
      } else {
        // Log registration failure
        firebaseService.recordError(
          'Registration failed: $error',
          null,
          context: {'user_type': 'trainer', 'error_type': 'registration'},
        );
        return error;
      }
    } catch (e, stackTrace) {
      // Record unexpected errors
      firebaseService.recordError(
        e,
        stackTrace,
        fatal: false,
        context: {'operation': 'trainer_registration'},
      );
      
      if (kDebugMode) {
        print('❌ Registration error: $e');
      }
      
      return 'An unexpected error occurred during registration. Please try again.';
    }
  }

  /// EXAMPLE 2: Real-time Data Listening with StreamBuilder Pattern
  static Stream<List<WorkoutRoutine>> getTrainerRoutinesStream(String trainerId) {
    try {
      return firestoreRepository
          .getTrainerRoutinesStream(trainerId)
          .handleError((error, stackTrace) {
            // Handle stream errors gracefully
            firebaseService.recordError(
              error,
              stackTrace,
              context: {'operation': 'routine_stream', 'trainerId': trainerId},
            );
            
            if (kDebugMode) {
              print('❌ Routine stream error: $error');
            }
          });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to create routine stream: $e');
      }
      return Stream.error(e);
    }
  }

  /// EXAMPLE 3: Paginated Data Loading
  static Future<List<UserData>> getTrainersWithPagination({
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      // Log screen view for analytics
      firebaseService.logEvent('trainers_list_viewed', {
        'pagination_enabled': true,
        'limit': limit,
        'has_previous_page': lastDoc != null,
      });

      List<UserData> trainers = await firestoreRepository.getTrainers(
        limit: limit,
        lastDoc: lastDoc,
      );

      // Log successful data load
      firebaseService.logEvent('trainers_loaded', {
        'count': trainers.length,
        'is_first_page': lastDoc == null,
      });

      if (kDebugMode) {
        print('✅ Loaded ${trainers.length} trainers');
      }

      return trainers;
    } catch (e, stackTrace) {
      firebaseService.recordError(
        e,
        stackTrace,
        context: {'operation': 'get_trainers_paginated'},
      );
      
      if (kDebugMode) {
        print('❌ Failed to load trainers: $e');
      }
      
      return [];
    }
  }

  /// EXAMPLE 4: Complex Transaction with Multiple Collections
  static Future<String?> createClientWithRoutineExample({
    required String email,
    required String password,
    required String name,
    required String trainerId,
    required ClientMetrics metrics,
    required WorkoutRoutine initialRoutine,
  }) async {
    try {
      // First register the client
      final authService = AuthService();
      String? error = await authService.registerClient(
        email: email,
        password: password,
        name: name,
        trainerId: trainerId,
        weight: metrics.weight,
        height: metrics.height,
        age: metrics.age,
        goals: metrics.goals,
        gender: metrics.gender,
      );

      if (error != null) {
        return error;
      }

      // Get the newly created client ID
      String clientId = firebaseService.currentUser!.uid;

      // Use transaction for consistency
      await FirestoreHelper.runTransaction((transaction) async {
        // Create the initial routine
        WorkoutRoutine routineWithClient = WorkoutRoutine(
          id: '',
          clientId: clientId,
          trainerId: trainerId,
          title: initialRoutine.title,
          days: initialRoutine.days,
          notes: initialRoutine.notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Add routine to Firestore
        DocumentReference routineRef = FirestoreHelper.collection('routines').doc();
        transaction.set(routineRef, {
          ...routineWithClient.toFirestore(),
          'createdAt': FirestoreHelper.serverTimestamp,
        });
      });

      // Log successful creation
      firebaseService.logEvent('client_with_routine_created', {
        'trainer_id': trainerId,
        'routine_days': initialRoutine.days.length,
      });

      firebaseService.logSignup('email', role: 'client');

      return null; // Success
    } catch (e, stackTrace) {
      firebaseService.recordError(
        e,
        stackTrace,
        context: {'operation': 'create_client_with_routine'},
      );
      return 'Failed to create client account with routine. Please try again.';
    }
  }

  /// EXAMPLE 5: Offline-First Data Management
  static Future<List<WorkoutRoutine>> getClientRoutinesOfflineFirst(String clientId) async {
    try {
      // First try to get cached data (simplified example)
      List<WorkoutRoutine> cachedRoutines = await _getCachedRoutines(clientId);
      
      if (cachedRoutines.isNotEmpty) {
        if (kDebugMode) {
          print('📱 Using cached routines (${cachedRoutines.length} items)');
        }
        
        // Return cached data immediately and refresh in background
        _refreshRoutinesInBackground(clientId);
        return cachedRoutines;
      }

      // If no cache, fetch from server
      return await firestoreRepository.getClientRoutines(clientId);
    } catch (e, stackTrace) {
      firebaseService.recordError(
        e,
        stackTrace,
        context: {'operation': 'get_client_routines_offline_first'},
      );
      
      // Return empty list if everything fails
      return [];
    }
  }

  /// EXAMPLE 6: Bulk Operations with Batch Processing
  static Future<bool> bulkUpdateClientMetrics(
    List<String> clientIds,
    Map<String, dynamic> metricsUpdate,
  ) async {
    try {
      const int batchSize = 500; // Firestore batch limit
      
      for (int i = 0; i < clientIds.length; i += batchSize) {
        int end = (i + batchSize < clientIds.length) ? i + batchSize : clientIds.length;
        List<String> batchClientIds = clientIds.sublist(i, end);
        
        WriteBatch batch = FirestoreHelper.batch();
        
        for (String clientId in batchClientIds) {
          DocumentReference clientRef = FirestoreHelper.document('clients', clientId);
          batch.update(clientRef, {
            'metrics': metricsUpdate,
            'updatedAt': FirestoreHelper.serverTimestamp,
          });
        }
        
        await batch.commit();
        
        if (kDebugMode) {
          print('✅ Updated batch ${(i / batchSize).floor() + 1} of ${(clientIds.length / batchSize).ceil()}');
        }
      }

      firebaseService.logEvent('bulk_metrics_update', {
        'client_count': clientIds.length,
        'batch_count': (clientIds.length / batchSize).ceil(),
      });

      return true;
    } catch (e, stackTrace) {
      firebaseService.recordError(
        e,
        stackTrace,
        context: {'operation': 'bulk_update_client_metrics'},
      );
      return false;
    }
  }

  /// EXAMPLE 7: Aggregation Queries
  static Future<Map<String, dynamic>> getTrainerAnalytics(String trainerId) async {
    try {
      // Use parallel queries for better performance
      List<Future> futures = [
        firestoreRepository.getTrainerStats(trainerId),
        _getBasicRoutineStats(trainerId),
      ];

      List<dynamic> results = await Future.wait(futures);
      
      Map<String, int> basicStats = results[0] as Map<String, int>;
      Map<String, dynamic> routineStats = results[1] as Map<String, dynamic>;

      Map<String, dynamic> analytics = {
        'basic': basicStats,
        'routines': routineStats,
        'generated_at': DateTime.now().toIso8601String(),
      };

      firebaseService.logEvent('trainer_analytics_viewed', {
        'trainer_id': trainerId,
        'total_clients': basicStats['totalClients'],
        'total_routines': basicStats['totalRoutines'],
      });

      return analytics;
    } catch (e, stackTrace) {
      firebaseService.recordError(
        e,
        stackTrace,
        context: {'operation': 'get_trainer_analytics'},
      );
      return {'error': 'Failed to load analytics'};
    }
  }

  /// EXAMPLE 8: Real-time Collaboration (Live Updates)
  static Stream<WorkoutRoutine?> watchRoutineUpdates(String routineId) {
    return FirebaseFirestore.instance
        .collection('routines')
        .doc(routineId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return WorkoutRoutine.fromFirestore(snapshot);
          }
          return null;
        })
        .handleError((error) {
          firebaseService.recordError(
            error,
            null,
            context: {'operation': 'watch_routine_updates', 'routine_id': routineId},
          );
        });
  }

  /// EXAMPLE 9: Security Rules Testing Helper
  static Future<bool> testUserPermissions(
    String userId,
    String resourceType,
    String resourceId,
  ) async {
    try {
      return await firestoreRepository.checkUserPermission(
        userId,
        resourceType,
        resourceId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Permission check failed: $e');
      }
      return false; // Fail secure
    }
  }

  /// EXAMPLE 10: Error Recovery and Retry Logic
  static Future<T?> executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e, stackTrace) {
        attempt++;
        
        if (attempt >= maxRetries) {
          firebaseService.recordError(
            'Operation failed after $maxRetries attempts: $e',
            stackTrace,
            context: {'operation': operationName, 'final_attempt': 'true'},
          );
          rethrow;
        }
        
        if (kDebugMode) {
          print('⚠️  $operationName attempt $attempt failed: $e. Retrying in ${delay.inSeconds}s...');
        }
        
        await Future.delayed(delay * attempt); // Exponential backoff
      }
    }
    
    return null;
  }

  /// HELPER METHODS

  /// Get cached routines (placeholder - implement with shared_preferences or hive)
  static Future<List<WorkoutRoutine>> _getCachedRoutines(String clientId) async {
    // Implementation would use local storage
    // For now, return empty list to simulate no cache
    return [];
  }

  /// Refresh routines in background
  static void _refreshRoutinesInBackground(String clientId) {
    // Non-blocking background refresh
    firestoreRepository.getClientRoutines(clientId).catchError((e) {
      if (kDebugMode) {
        print('⚠️  Background refresh failed: $e');
      }
    });
  }

  /// Get basic routine statistics for trainer
  static Future<Map<String, dynamic>> _getBasicRoutineStats(String trainerId) async {
    try {
      // Get count of public vs private routines
      QuerySnapshot publicRoutines = await FirebaseFirestore.instance
          .collection('routines')
          .where('trainerId', isEqualTo: trainerId)
          .where('isPublic', isEqualTo: true)
          .get();

      QuerySnapshot allRoutines = await FirebaseFirestore.instance
          .collection('routines')
          .where('trainerId', isEqualTo: trainerId)
          .get();

      return {
        'total_routines': allRoutines.docs.length,
        'public_routines': publicRoutines.docs.length,
        'private_routines': allRoutines.docs.length - publicRoutines.docs.length,
      };
    } catch (e) {
      return {
        'total_routines': 0,
        'public_routines': 0,
        'private_routines': 0,
      };
    }
  }

  /// USAGE PATTERNS DOCUMENTATION
  
  /// Example of proper StreamBuilder usage with Firebase:
  /// 
  /// ```dart
  /// StreamBuilder<List<WorkoutRoutine>>(
  ///   stream: FirebaseExamples.getTrainerRoutinesStream(trainerId),
  ///   builder: (context, snapshot) {
  ///     if (snapshot.hasError) {
  ///       return Text('Error: ${snapshot.error}');
  ///     }
  ///     
  ///     if (snapshot.connectionState == ConnectionState.waiting) {
  ///       return CircularProgressIndicator();
  ///     }
  ///     
  ///     List<WorkoutRoutine> routines = snapshot.data ?? [];
  ///     return ListView.builder(
  ///       itemCount: routines.length,
  ///       itemBuilder: (context, index) => RoutineListItem(
  ///         routine: routines[index],
  ///       ),
  ///     );
  ///   },
  /// )
  /// ```
  
  /// Example of proper FutureBuilder usage with Firebase:
  /// 
  /// ```dart
  /// FutureBuilder<List<UserData>>(
  ///   future: FirebaseExamples.getTrainersWithPagination(),
  ///   builder: (context, snapshot) {
  ///     if (snapshot.hasError) {
  ///       return ErrorWidget(snapshot.error);
  ///     }
  ///     
  ///     if (snapshot.connectionState == ConnectionState.done) {
  ///       List<UserData> trainers = snapshot.data ?? [];
  ///       return TrainersList(trainers: trainers);
  ///     }
  ///     
  ///     return LoadingSpinner();
  ///   },
  /// )
  /// ```
}