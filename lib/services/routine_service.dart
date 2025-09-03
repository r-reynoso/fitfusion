import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'environment_service.dart';

abstract class RoutineItem {
  Map<String, dynamic> toMap();
}

class Exercise extends RoutineItem {
  final String name;
  final String reps;
  final String sets;
  final String? notes;

  Exercise({
    required this.name,
    required this.reps,
    required this.sets,
    this.notes,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      reps: map['reps'] ?? '',
      sets: map['sets'] ?? '',
      notes: map['notes'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'exercise',
      'name': name,
      'reps': reps,
      'sets': sets,
      'notes': notes,
    };
  }
}

class RoutineDivider extends RoutineItem {
  final String? label;

  RoutineDivider({this.label});

  factory RoutineDivider.fromMap(Map<String, dynamic> map) {
    return RoutineDivider(
      label: map['label'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'divider',
      'label': label,
    };
  }
}

class RoutineDay {
  final String day;
  final List<RoutineItem> items;

  RoutineDay({
    required this.day,
    required this.items,
  });

  // Backward compatibility getter
  List<Exercise> get exercises => items.whereType<Exercise>().toList();

  factory RoutineDay.fromMap(Map<String, dynamic> map) {
    List<RoutineItem> items = [];
    
    // Handle new format with items
    if (map['items'] != null) {
      items = (map['items'] as List<dynamic>).map((item) {
        Map<String, dynamic> itemMap = item as Map<String, dynamic>;
        String type = itemMap['type'] ?? 'exercise';
        
        if (type == 'divider') {
          return RoutineDivider.fromMap(itemMap);
        } else {
          return Exercise.fromMap(itemMap);
        }
      }).toList();
    } 
    // Handle old format with exercises only
    else if (map['exercises'] != null) {
      items = (map['exercises'] as List<dynamic>)
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    
    return RoutineDay(
      day: map['day'] ?? '',
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'items': items.map((item) => item.toMap()).toList(),
      // Keep backward compatibility
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

class WorkoutRoutine {
  final String id;
  final String clientId;
  final String trainerId;
  final String title;
  final List<RoutineDay> days;
  final String? notes;
  final bool isPublic;
  final String? publicToken;
  final DateTime? publicExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutRoutine({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.title,
    required this.days,
    this.notes,
    this.isPublic = false,
    this.publicToken,
    this.publicExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutRoutine.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WorkoutRoutine(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      title: data['title'] ?? '',
      days: (data['days'] as List<dynamic>?)
          ?.map((d) => RoutineDay.fromMap(d as Map<String, dynamic>))
          .toList() ?? [],
      notes: data['notes'],
      isPublic: data['isPublic'] ?? false,
      publicToken: data['publicToken'],
      publicExpiresAt: data['publicExpiresAt']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'title': title,
      'days': days.map((d) => d.toMap()).toList(),
      'notes': notes,
      'isPublic': isPublic,
      'publicToken': publicToken,
      'publicExpiresAt': publicExpiresAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class RoutineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Always use production Firebase
  bool get _isProduction => EnvironmentService.isProduction;

  Future<List<WorkoutRoutine>> getTrainerRoutines(String trainerId, {int page = 0, int limit = 25}) async {
    try {
      Query query = _firestore
          .collection('routines')
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (page > 0) {
        QuerySnapshot previousPage = await _firestore
            .collection('routines')
            .where('trainerId', isEqualTo: trainerId)
            .orderBy('updatedAt', descending: true)
            .limit(page * limit)
            .get();

        if (previousPage.docs.isNotEmpty) {
          query = query.startAfterDocument(previousPage.docs.last);
        }
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => WorkoutRoutine.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting trainer routines: $e');
      return [];
    }
  }

  Future<List<WorkoutRoutine>> getClientRoutines(String clientId, {int page = 0, int limit = 25}) async {
    try {
      Query query = _firestore
          .collection('routines')
          .where('clientId', isEqualTo: clientId)
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (page > 0) {
        QuerySnapshot previousPage = await _firestore
            .collection('routines')
            .where('clientId', isEqualTo: clientId)
            .orderBy('updatedAt', descending: true)
            .limit(page * limit)
            .get();

        if (previousPage.docs.isNotEmpty) {
          query = query.startAfterDocument(previousPage.docs.last);
        }
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => WorkoutRoutine.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting client routines: $e');
      return [];
    }
  }

  Future<WorkoutRoutine?> getRoutineById(String routineId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('routines')
          .doc(routineId)
          .get();

      if (doc.exists) {
        return WorkoutRoutine.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting routine: $e');
      return null;
    }
  }

  Future<WorkoutRoutine?> getRoutineByToken(String token) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('routines')
          .where('publicToken', isEqualTo: token)
          .where('isPublic', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        WorkoutRoutine routine = WorkoutRoutine.fromFirestore(snapshot.docs.first);
        
        // Check if token is expired
        if (routine.publicExpiresAt != null && 
            routine.publicExpiresAt!.isBefore(DateTime.now())) {
          return null;
        }
        
        return routine;
      }
      return null;
    } catch (e) {
      print('Error getting routine by token: $e');
      return null;
    }
  }

  Future<String?> createRoutine(WorkoutRoutine routine) async {
    try {
      // Validate routine data
      if (routine.title.trim().isEmpty) {
        return null; // Invalid routine
      }
      if (routine.days.isEmpty) {
        return null; // Invalid routine
      }

      Map<String, dynamic> routineData = routine.toFirestore();
      routineData['createdAt'] = FieldValue.serverTimestamp();

      DocumentReference docRef = await _firestore
          .collection('routines')
          .add(routineData);

      return docRef.id;
    } catch (e) {
      print('Error creating routine: $e');
      return null;
    }
  }

  Future<bool> updateRoutine(String routineId, WorkoutRoutine routine) async {
    try {
      // Validate routine data
      if (routine.title.trim().isEmpty || routine.days.isEmpty) {
        return false;
      }

      await _firestore
          .collection('routines')
          .doc(routineId)
          .update(routine.toFirestore());

      return true;
    } catch (e) {
      print('Error updating routine: $e');
      return false;
    }
  }

  Future<bool> deleteRoutine(String routineId) async {
    try {
      await _firestore
          .collection('routines')
          .doc(routineId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting routine: $e');
      return false;
    }
  }

  Future<String> generatePublicToken(String routineId, DateTime? expiresAt) async {
    try {
      // Generate a secure token
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String randomStr = Random.secure().nextInt(999999).toString().padLeft(6, '0');
      String input = '$routineId-$timestamp-$randomStr';
      
      var bytes = utf8.encode(input);
      var digest = sha256.convert(bytes);
      String token = digest.toString().substring(0, 24); // 24 char token

      // Update routine with public token using transaction for consistency
      await _firestore.runTransaction((transaction) async {
        DocumentReference routineRef = _firestore.collection('routines').doc(routineId);
        DocumentSnapshot routineSnapshot = await transaction.get(routineRef);
        
        if (!routineSnapshot.exists) {
          throw Exception('Routine not found');
        }
        
        transaction.update(routineRef, {
          'isPublic': true,
          'publicToken': token,
          'publicExpiresAt': expiresAt,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return token;
    } catch (e) {
      print('Error generating public token: $e');
      throw Exception('Failed to generate public token');
    }
  }

  Future<bool> revokePublicAccess(String routineId) async {
    try {
      await _firestore
          .collection('routines')
          .doc(routineId)
          .update({
        'isPublic': false,
        'publicToken': FieldValue.delete(),
        'publicExpiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error revoking public access: $e');
      return false;
    }
  }

  Future<bool> deleteAllClientRoutines(String clientId) async {
    try {
      // Use batch delete for better performance
      WriteBatch batch = _firestore.batch();
      
      // Get all routines for this client
      QuerySnapshot snapshot = await _firestore
          .collection('routines')
          .where('clientId', isEqualTo: clientId)
          .get();
      
      // Add delete operations to batch
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Commit batch delete
      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting client routines: $e');
      return false;
    }
  }

  // Get routine statistics for admin/analytics
  Future<Map<String, dynamic>> getRoutineStats() async {
    try {
      QuerySnapshot allRoutines = await _firestore.collection('routines').get();
      QuerySnapshot publicRoutines = await _firestore
          .collection('routines')
          .where('isPublic', isEqualTo: true)
          .get();

      return {
        'totalRoutines': allRoutines.docs.length,
        'publicRoutines': publicRoutines.docs.length,
        'privateRoutines': allRoutines.docs.length - publicRoutines.docs.length,
      };
    } catch (e) {
      print('Error getting routine stats: $e');
      return {'totalRoutines': 0, 'publicRoutines': 0, 'privateRoutines': 0};
    }
  }

  // Search routines (for admin/reporting)
  Future<List<WorkoutRoutine>> searchRoutines(String query, {int limit = 50}) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a simple title search. For production, consider Algolia or Elasticsearch
      QuerySnapshot snapshot = await _firestore
          .collection('routines')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => WorkoutRoutine.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error searching routines: $e');
      return [];
    }
  }
}