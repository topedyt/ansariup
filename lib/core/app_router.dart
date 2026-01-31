import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper for listening to streams
import 'go_router_refresh_stream.dart';

// Screen Imports
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/library/presentation/saved_questions_screen.dart';
import '../../features/library/presentation/subject_list_screen.dart';
import '../../features/library/presentation/chapter_list_screen.dart';
import '../../features/library/presentation/quiz_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/library/presentation/leaderboard_screen.dart';
import '../../features/payment/presentation/subscription_screen.dart';

// NOTE: I renamed this to 'appRouterProvider' to match your main.dart
final appRouterProvider = Provider<GoRouter>((ref) {
  // Get the auth client
  final authClient = Supabase.instance.client.auth;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true, // Shows navigation logs in console

    // 1. LISTEN TO AUTH CHANGES
    refreshListenable: GoRouterRefreshStream(authClient.onAuthStateChange),

    // 2. REDIRECT LOGIC
    redirect: (context, state) {
      final isLoggedIn = authClient.currentUser != null;

      final isLoggingIn = state.uri.toString() == '/login';
      final isSigningUp = state.uri.toString() == '/signup';

      // If not logged in & trying to access app -> Login
      if (!isLoggedIn && !isLoggingIn && !isSigningUp) {
        return '/login';
      }

      // If logged in & trying to access auth screens -> Home
      if (isLoggedIn && (isLoggingIn || isSigningUp)) {
        return '/';
      }

      return null;
    },

    routes: [
      // Home
      GoRoute(
        path: '/',
        builder: (context, state) => const SubjectListScreen(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // --- LIBRARY ROUTES (FIXED) ---

      // FIX 1: Changed '/subject/:id' to '/chapters/:subjectId'
      // This matches what SubjectListScreen is pushing.
      GoRoute(
        path: '/chapters/:subjectId',
        builder: (context, state) {
          final idStr = state.pathParameters['subjectId'];
          final id = int.tryParse(idStr ?? '') ?? 0;
          return ChapterListScreen(subjectId: id);
        },
      ),

      // FIX 2: Quiz Route matches your Logic
      GoRoute(
        path: '/quiz/:chapterId',
        builder: (context, state) {
          // 1. Path Parameter (The Chapter ID)
          final idStr = state.pathParameters['chapterId'];
          final id = int.tryParse(idStr ?? '') ?? 0;

          // 2. Query Parameters (Settings like mode & count)
          final mode = state.uri.queryParameters['mode'] ?? 'practice';
          final countStr = state.uri.queryParameters['count'] ?? '10';
          final count = int.tryParse(countStr) ?? 10;

          return QuizScreen(chapterId: id, mode: mode, questionCount: count);
        },
      ),

      GoRoute(
        path: '/quiz/random',
        builder: (context, state) {
          return const QuizScreen(
            chapterId: 0, // 0 = Random Mode
            mode: 'practice', // Practice = No Timer, Instant Feedback
            questionCount: 9999, // "Unlimited" visual indicator
          );
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedQuestionsScreen(),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
    ],
  );
});
