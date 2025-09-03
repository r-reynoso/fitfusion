import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/trainer/trainer_dashboard.dart';
import 'screens/trainer/routine_edit_screen.dart';
import 'screens/client/client_dashboard.dart';
import 'screens/public/public_routine_screen.dart';
import 'screens/client/edit_stats_screen.dart';
import 'screens/splash_screen.dart';

class FitFusionRouter {
  static final AuthService _authService = AuthService();
  
  static final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/trainer/:trainerId/clients',
        builder: (context, state) {
          final trainerId = state.pathParameters['trainerId']!;
          return TrainerDashboard(trainerId: trainerId);
        },
      ),
      GoRoute(
        path: '/trainer/:trainerId/routines/:routineId/edit',
        builder: (context, state) {
          final trainerId = state.pathParameters['trainerId']!;
          final routineId = state.pathParameters['routineId']!;
          final clientId = state.uri.queryParameters['clientId'];
          return RoutineEditScreen(
            trainerId: trainerId,
            routineId: routineId == 'new' ? null : routineId,
            clientId: clientId,
          );
        },
      ),
      GoRoute(
        path: '/client/:clientId/routines',
        builder: (context, state) {
          final clientId = state.pathParameters['clientId']!;
          return ClientDashboard(clientId: clientId);
        },
      ),
      GoRoute(
        path: '/client/:clientId/edit-stats',
        builder: (context, state) {
          final clientId = state.pathParameters['clientId']!;
          return EditStatsScreen(clientId: clientId);
        },
      ),
      GoRoute(
        path: '/r/:publicToken',
        builder: (context, state) {
          final publicToken = state.pathParameters['publicToken']!;
          return PublicRoutineScreen(publicToken: publicToken);
        },
      ),
    ],
    redirect: (context, state) async {
      // Public routine pages don't require authentication
      if (state.fullPath?.startsWith('/r/') == true) {
        return null;
      }
      
      // If on splash screen, let it handle the redirect
      if (state.fullPath == '/splash') {
        return null;
      }
      
      // Check authentication status (works for both Firebase and demo mode)
      final userData = await _authService.getCurrentUserData();
      final isLoggedIn = userData != null;
      
      // If not logged in and not on auth screens, redirect to login
      if (!isLoggedIn && 
          state.fullPath != '/login' && 
          state.fullPath != '/register') {
        return '/login';
      }
      
      // If logged in and on auth screens, redirect to appropriate dashboard
      if (isLoggedIn && 
          (state.fullPath == '/login' || state.fullPath == '/register')) {
        if (userData.role == UserRole.trainer) {
          return '/trainer/${userData.id}/clients';
        } else {
          return '/client/${userData.id}/routines';
        }
      }
      
      return null;
    },
  );
  
  static GoRouter get router => _router;
}