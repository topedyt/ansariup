import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_router.dart';

// 1. Create a provider for the Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// 2. The FutureProvider for initialization
final initializationProvider = FutureProvider<void>((ref) async {
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Only responsible for showing the loading spinner while Supabase warms up
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInitialization = ref.watch(initializationProvider);

    return asyncInitialization.when(
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Initialization Error: $err')),
        ),
      ),
      // ✅ SUCCESS: Now we load the REAL app which has the listener
      data: (_) => const _MainApp(),
    );
  }
}

/// The actual App widget containing the Router and the Deep Link Listener
class _MainApp extends ConsumerStatefulWidget {
  const _MainApp();

  @override
  ConsumerState<_MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<_MainApp> {
  @override
  void initState() {
    super.initState();
    
    // 👇 THIS IS THE MAGIC LISTENER 👇
    // It detects if the app was opened via the "Reset Password" email link
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // Force navigation to the update password screen
        ref.read(appRouterProvider).push('/update-password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'Adhinasth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}