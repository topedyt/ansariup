import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import '../auth_providers.dart';
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- GOOGLE SIGN IN LOGIC ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

      if (webClientId.isEmpty) {
        throw 'Google Client ID is missing in .env file';
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId, 
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;

      if (googleAuth == null) {
        throw 'Google Sign In cancelled.';
      }

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        context.go('/'); // Navigate to Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final authState = ref.watch(authControllerProvider);
    final isEmailLoading = authState.isLoading;
    final isLoading = isEmailLoading || _isGoogleLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.error.toString().replaceAll("Exception:", "").trim()),
              backgroundColor: Colors.redAccent),
        );
      }
    });

    return Scaffold(
      body: MeshBackground(
        theme: theme,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. LOGO ICON (With Fallback)
                  ClayContainer(
                    height: 100,
                    width: 100,
                    borderRadius: 50,
                    color: theme.cardColor,
                    parentColor: theme.bgGradient.first,
                    emboss: true,
                    spread: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        // 🔍 ZOOM FIX: Scale up to remove internal padding
                        child: Transform.scale(
                          scale: 1.3, // Zoom level (1.4 fills the 70% content to ~100%)
                          child: Image.asset(
                            'assets/icons/icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.lock_person_rounded,
                                  size: 40, color: theme.accentColor);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. HEADLINE 
                  Text(
                    "Welcome Back",
                    style: GoogleFonts.inter( 
                      fontSize: 30, 
                      fontWeight: FontWeight.w600, 
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign in to continue your progress.",
                    style: GoogleFonts.inter( 
                        color: theme.subTextColor, 
                        fontSize: 15,
                        fontWeight: FontWeight.w400
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 3. INPUT FIELDS
                  _ClayTextField(
                      controller: _emailController,
                      hint: "Email Address",
                      icon: Icons.email_rounded,
                      theme: theme),
                  const SizedBox(height: 20),

                  _ClayTextField(
                      controller: _passwordController,
                      hint: "Password",
                      icon: Icons.lock_rounded,
                      theme: theme,
                      isPassword: true),

                  // ✅ FIXED FORGOT PASSWORD BUTTON (Tappable & Debuggable)
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent, 
                      child: InkWell(
                        onTap: () {
                          // 👇 Check your Debug Console for this print!
                          print("Forgot Password Tapped!"); 
                          try {
                             context.push('/forgot-password');
                          } catch (e) {
                             print("Navigation Error: $e");
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text("Nav Error: $e")),
                             );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Big Touch Area
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.inter(
                              color: theme.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 4. LOGIN BUTTON
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            ref.read(authControllerProvider.notifier).login(
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                          },
                    child: ClayContainer(
                      height: 56,
                      width: double.infinity,
                      borderRadius: 16,
                      color: theme.accentColor,
                      parentColor: theme.bgGradient.first,
                      emboss: isEmailLoading,
                      spread: 3,
                      child: Center(
                        child: isEmailLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text("SIGN IN",
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.5)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // OR DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.subTextColor.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text("OR",
                            style: GoogleFonts.inter(
                                color: theme.subTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: theme.subTextColor.withOpacity(0.2))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. GOOGLE SIGN IN BUTTON
                  GestureDetector(
                    onTap: isLoading ? null : _handleGoogleSignIn,
                    child: ClayContainer(
                      height: 56,
                      width: double.infinity,
                      borderRadius: 16,
                      color: theme.cardColor,
                      parentColor: theme.bgGradient.first,
                      emboss: _isGoogleLoading,
                      child: Center(
                        child: _isGoogleLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) => 
                                      const Icon(Icons.public, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Sign in with Google",
                                    style: GoogleFonts.inter(
                                      color: theme.textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 6. SIGNUP LINK
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: RichText(
                      text: TextSpan(
                        text: "New here? ",
                        style: GoogleFonts.inter(color: theme.subTextColor, fontSize: 14),
                        children: [
                          TextSpan(
                            text: "Create Account",
                            style: GoogleFonts.inter(
                                color: theme.accentColor,
                                fontWeight: FontWeight.w700),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClayTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final dynamic theme;
  final bool isPassword;

  const _ClayTextField(
      {required this.controller,
      required this.hint,
      required this.icon,
      required this.theme,
      this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      height: 56,
      borderRadius: 16,
      color: theme.cardColor,
      parentColor: theme.bgGradient.first,
      emboss: true,
      spread: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.inter(color: theme.textColor, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            icon: Icon(icon, color: theme.subTextColor, size: 20),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: theme.subTextColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}