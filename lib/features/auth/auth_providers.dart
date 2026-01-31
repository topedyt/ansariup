import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Auth Repository: Handles the actual Supabase calls
class AuthRepository {
  final SupabaseClient _supabase;
  AuthRepository(this._supabase);

  Future<void> login(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signup(String email, String password, String name) async {
    final response = await _supabase.auth.signUp(
      email: email, 
      password: password,
      data: {'full_name': name}, // Store name in metadata
    );
    if (response.user == null) {
      throw Exception("Signup failed: User is null");
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
  
  User? get currentUser => _supabase.auth.currentUser;
}

// 2. Providers

// Core Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

// ✅ NEW: Secure Admin Check Provider
// This calls the 'am_i_admin' function on your database.
// It returns TRUE only if the server says so.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  
  // If not logged in, definitely not admin
  if (user == null) return false;

  try {
    // 🔒 SECURE: Ask the database "Is this user an admin?"
    // The logic stays on the server, not in your app code.
    final bool isAdmin = await Supabase.instance.client.rpc('am_i_admin');
    return isAdmin;
  } catch (e) {
    // If any error occurs (network, hacking attempt, etc.), fail safely to false.
    return false;
  }
});

// Auth Controller Provider (Manages UI State)
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

// 3. Controller: Handles UI state (Loading/Error)
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AsyncValue.data(null));

  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repo.login(email, password);
      state = const AsyncValue.data(null);
      return null; // No error
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.toString(); // Return error message
    }
  }

  Future<String?> signup(String email, String password, String name) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signup(email, password, name);
      state = const AsyncValue.data(null);
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
  }
}