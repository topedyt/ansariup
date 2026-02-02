import 'package:flutter/foundation.dart'; // ✅ Needed for kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper for listening to streams
import 'go_router_refresh_stream.dart';

// Screens
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/update_password_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/profile_screen.dart';

// Library Imports
import '../features/library/presentation/saved_questions_screen.dart';
import '../features/library/presentation/subject_list_screen.dart';
import '../features/library/presentation/chapter_list_screen.dart';
import '../features/library/presentation/quiz_screen.dart';
import '../features/library/presentation/leaderboard_screen.dart';

// Admin & Payment
import '../features/admin/presentation/admin_screen.dart';
import '../features/admin/presentation/payment_admin_screen.dart'; // ✅ NEW IMPORT
import '../features/payment/presentation/subscription_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authClient = Supabase.instance.client.auth;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authClient.onAuthStateChange),

    redirect: (context, state) {
      final isLoggedIn = authClient.currentUser != null;
      final isLoggingIn = state.uri.toString() == '/login';
      final isSigningUp = state.uri.toString() == '/signup';
      final isRecovering = state.uri.toString() == '/update-password';
      final isForgot = state.uri.toString() == '/forgot-password';

      // ---------------------------------------------------------
      // 🔒 SMART WEB LOCK: Vercel = Payment Only | Localhost = Unlocked
      // ---------------------------------------------------------
      if (kIsWeb) {
        // Detect if we are on the live site or testing locally
        final host = Uri.base.host;
        final isProduction = host.contains('vercel.app'); 

        // 1. If not logged in, force Login (or Signup/Recovery pages)
        if (!isLoggedIn) {
          if (isLoggingIn || isSigningUp || isRecovering || isForgot) return null;
          return '/login';
        }

        // 2. IF PRODUCTION (Vercel): FORCE them to Subscription Screen
        if (isProduction) {
          // Allow staying on subscription
          if (state.uri.toString() == '/subscription') return null;
          
          // Redirect everything else (Home, Quiz, etc.) to Subscription
          return '/subscription';
        }

        // 3. IF LOCALHOST: Do nothing here. 
        // It falls through to the Standard Logic below, allowing full access.
      }
      // ---------------------------------------------------------

      // 📱 STANDARD APP LOGIC (Mobile + Localhost Web)

      // If not logged in & trying to access app -> Login
      if (!isLoggedIn && !isLoggingIn && !isSigningUp && !isRecovering && !isForgot) {
        return '/login';
      }

      // If logged in & trying to access auth screens -> Home
      if (isLoggedIn && (isLoggingIn || isSigningUp || isForgot)) {
        return '/';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SubjectListScreen(),
      ),
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
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/update-password',
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/chapters/:subjectId',
        builder: (context, state) {
          final idStr = state.pathParameters['subjectId'];
          final id = int.tryParse(idStr ?? '') ?? 0;
          return ChapterListScreen(subjectId: id);
        },
      ),
      GoRoute(
        path: '/quiz/:chapterId',
        builder: (context, state) {
          final idStr = state.pathParameters['chapterId'];
          final id = int.tryParse(idStr ?? '') ?? 0;
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
            chapterId: 0,
            mode: 'practice',
            questionCount: 9999,
          );
        },
      ),
      // 👑 Main Admin Dashboard
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      // 💳 Payment Approval Dashboard (Linked from Admin Screen)
      GoRoute(
        path: '/admin-payments',
        builder: (context, state) => const PaymentAdminScreen(),
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