import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Providers
import '../auth_providers.dart'; // Ensure isAdminProvider is here
import '../../library/library_providers.dart'; 
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

// Admin Screens
import '../../admin/presentation/payment_admin_screen.dart'; 

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // --- HELPER METHODS ---
  Future<void> _launchContact(String subject) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'topedyt@gmail.com', 
      query: 'subject=$subject',
    );
    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('Could not launch email');
    }
  }

  Future<void> _launchPrivacy() async {
    final Uri url = Uri.parse('https://docs.google.com/document/d/1qlNculQTAXoYH5YK9-TOMez6McGwBEwyoB042aw7574/edit?usp=sharing');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch url');
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This action cannot be undone. All your progress will be lost permanently."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authControllerProvider.notifier).logout();
                if(context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion request sent.")));
                }
              } catch (e) {
                // error
              }
            }, 
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final isProAsync = ref.watch(isUserProProvider);
    
    // ✅ SECURE ADMIN CHECK: Watches the database function result
    final isAdminAsync = ref.watch(isAdminProvider);
    
    final theme = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    final isSystemDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && isSystemDark);

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- APP BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                      onPressed: () => context.pop(),
                    ),
                    Text(
                      "Player Profile", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.textColor)
                    ),
                    const SizedBox(width: 48), 
                  ],
                ),
              ),

              // --- SCROLLABLE CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 1. SCULPTED AVATAR HERO
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClayContainer(
                            height: 110, width: 110, borderRadius: 55,
                            color: theme.cardColor,
                            parentColor: theme.bgGradient.first,
                            spread: 4,
                            emboss: false, 
                            child: Center(
                              child: Text(
                                user.userMetadata?['full_name']?.substring(0, 1).toUpperCase() ?? "A",
                                style: GoogleFonts.nunito(
                                  fontSize: 45, 
                                  fontWeight: FontWeight.w900, 
                                  color: theme.accentColor
                                ),
                              ),
                            ),
                          ),
                          ClayContainer(
                            height: 32, width: 32, borderRadius: 16,
                            color: theme.accentColor,
                            emboss: false,
                            child: const Icon(Icons.edit, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Text(
                        user.userMetadata?['full_name'] ?? "Aspirant",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.textColor),
                      ),
                      Text(
                        user.email ?? "", 
                        style: TextStyle(fontSize: 13, color: theme.subTextColor, fontWeight: FontWeight.w600),
                      ),
                      
                      const SizedBox(height: 32),

                      // 2. STATUS ROW (Pro + Dark Mode)
                      Row(
                        children: [
                          // PRO STATUS TILE
                          Expanded(
                            flex: 3,
                            child: isProAsync.when(
                              data: (isPro) => _BentoTile(
                                title: isPro ? "PRO" : "UPGRADE",
                                subtitle: isPro ? "Active" : "Get Pro",
                                icon: isPro ? Icons.star_rounded : Icons.bolt_rounded,
                                color: isPro ? const Color(0xFFFFD700) : theme.accentColor,
                                theme: theme,
                                onTap: isPro ? null : () => context.push('/subscription'),
                                isSolidColor: isPro, 
                              ),
                              loading: () => const SizedBox(height: 80),
                              error: (_,__) => const SizedBox(height: 80),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // DARK MODE TILE
                          Expanded(
                            flex: 2,
                            child: _BentoTile(
                              title: "THEME",
                              subtitle: isDark ? "Dark" : "Light",
                              icon: isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                              color: Colors.blueGrey,
                              theme: theme,
                              onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 3. MAIN ACTION GRID (2x2)
                      Row(
                        children: [
                          Expanded(
                            child: _BentoTile(
                              title: "Leaderboard",
                              subtitle: "Global Rank",
                              icon: Icons.emoji_events_rounded,
                              color: Colors.amber,
                              theme: theme,
                              onTap: () => context.push('/leaderboard'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BentoTile(
                              title: "Saved",
                              subtitle: "Bookmarks",
                              icon: Icons.bookmark_rounded,
                              color: Colors.teal,
                              theme: theme,
                              onTap: () => context.push('/saved'),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _BentoTile(
                              title: "History",
                              subtitle: "Past Tests",
                              icon: Icons.history_rounded,
                              color: Colors.blueAccent,
                              theme: theme,
                              onTap: () {
                                // TODO: Navigate to history
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BentoTile(
                              title: "Share",
                              subtitle: "Invite",
                              icon: Icons.share_rounded,
                              color: Colors.green,
                              theme: theme,
                              onTap: () {
                                // TODO: Share logic
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // 4. ADMIN PANEL SECTION (SECURE)
                      isAdminAsync.when(
                        data: (isAdmin) {
                          // Hides UI completely if server says "Not Admin"
                          if (!isAdmin) return const SizedBox.shrink(); 

                          return Column(
                            children: [
                              // A. Question Admin
                              _BentoWideTile(
                                title: "Question Admin",
                                icon: Icons.admin_panel_settings_rounded,
                                color: Colors.redAccent,
                                theme: theme,
                                onTap: () => context.push('/admin'),
                              ),
                              const SizedBox(height: 16),

                              // B. Payment Verification
                              _BentoWideTile(
                                title: "Verify Payments",
                                icon: Icons.verified_user_rounded,
                                color: Colors.indigoAccent,
                                theme: theme,
                                onTap: () {
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (_) => const PaymentAdminScreen())
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_,__) => const SizedBox.shrink(),
                      ),
                      
                      // 5. CONTACT US
                      _BentoWideTile(
                        title: "Contact Us",
                        icon: Icons.support_agent_rounded,
                        color: Colors.blueAccent,
                        theme: theme,
                        onTap: () => _launchContact("Support Request - ${user.email}"),
                      ),

                      const SizedBox(height: 16),

                      // 6. LEGAL & DELETE
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _launchPrivacy,
                              child: ClayContainer(
                                height: 50, borderRadius: 16,
                                color: theme.cardColor, parentColor: theme.bgGradient.last, emboss: false,
                                child: Center(
                                  child: Text("Privacy Policy", style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _deleteAccount(context, ref),
                              child: ClayContainer(
                                height: 50, borderRadius: 16,
                                color: const Color(0xFFFFEBEE), parentColor: theme.bgGradient.last, emboss: false,
                                child: const Center(
                                  child: Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 7. LOGOUT
                      _BentoWideTile(
                        title: "Log Out",
                        icon: Icons.logout_rounded,
                        color: theme.subTextColor,
                        theme: theme,
                        onTap: () async {
                          await ref.read(authControllerProvider.notifier).logout();
                        },
                      ),

                      const SizedBox(height: 20),
                      Text("v1.0.0", style: TextStyle(color: theme.subTextColor, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER: SQUARE BENTO TILE ---
class _BentoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final AppTheme theme;
  final VoidCallback? onTap;
  final bool isSolidColor;

  const _BentoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.theme,
    this.onTap,
    this.isSolidColor = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        height: 110,
        borderRadius: 24,
        color: isSolidColor ? color : theme.cardColor,
        parentColor: theme.bgGradient.last,
        emboss: false,
        spread: 3,
        child: Stack(
          children: [
            // Background Icon Faded
            Positioned(
              right: -10, bottom: -10,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(icon, size: 70, color: (isSolidColor ? Colors.black : color).withOpacity(0.08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSolidColor ? Colors.black : color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: isSolidColor ? Colors.black : color, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(), 
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w900, 
                          color: isSolidColor ? Colors.black54 : theme.subTextColor,
                          letterSpacing: 0.5
                        )
                      ),
                      Text(
                        subtitle, 
                        style: TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.bold, 
                          color: isSolidColor ? Colors.black : theme.textColor
                        )
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER: WIDE BENTO TILE ---
class _BentoWideTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AppTheme theme;
  final VoidCallback onTap;

  const _BentoWideTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        height: 60,
        borderRadius: 20,
        color: theme.cardColor,
        parentColor: theme.bgGradient.last,
        emboss: true, 
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                title, 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)
              ),
            ],
          ),
        ),
      ),
    );
  }
}