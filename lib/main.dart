
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
  // No need to interact with ref here, just complete the future.
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the initialization provider
    final asyncInitialization = ref.watch(initializationProvider);

    // Use a pattern switch to decide what to show
    return asyncInitialization.when(
      // While loading, show a simple centered spinner.
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      // If there's an error, display it.
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Initialization Error: $err'),
          ),
        ),
      ),
      // When data is loaded (initialization is complete), build the main app.
      data: (_) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          title: 'Adhinasth',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
