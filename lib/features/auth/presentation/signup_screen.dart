import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Clean Fonts
import 'package:slider_captcha/slider_captcha.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart'; // Import main.dart to get the supabaseProvider
import '../auth_providers.dart';
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      // ⚠️ Use your REAL Client ID here (same as Login Screen)
      const webClientId =
          '1070502078318-c6fldur504bkhd116ic72ru5fud0lube.apps.googleusercontent.com';
      const iosClientId = 'YOUR-IOS-CLIENT-ID.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;

      if (googleAuth == null) throw 'Google Sign In cancelled.';

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) throw 'No ID Token found.';

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sign Up Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _verifyCaptcha() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF2D3436),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Security Check",
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 10),
                Text("Slide to verify you are human",
                    style: GoogleFonts.inter(color: Colors.white70)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: SliderCaptcha(
                    controller: SliderController(),
                    image: Container(
                      color: Colors.blueGrey,
                      child: const Center(
                          child: Icon(Icons.security,
                              size: 64, color: Colors.white24)),
                    ),
                    colorBar: const Color(0xFF2D3436),
                    colorCaptChar: Colors.blueAccent,
                    onConfirm: (bool value) async {
                      if (value) {
                        Navigator.of(context).pop();
                        await _handleSignup();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).signup(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _nameController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOtpInput(_emailController.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceAll("Exception:", "").trim()),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showOtpInput(String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    final supabase = ref.read(supabaseProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2D3436),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("Enter Code",
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("We sent a 6-digit code to\n$email",
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 24, letterSpacing: 5),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel", style: GoogleFonts.inter())),
              TextButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        if (otpController.text.length != 6) return;
                        setDialogState(() => isVerifying = true);

                        try {
                          final response = await supabase.auth.verifyOTP(
                            token: otpController.text.trim(),
                            type: OtpType.signup,
                            email: email,
                          );
                          if (!context.mounted) return;
                          if (response.session != null) {
                            Navigator.of(context).pop();
                            if (mounted) {
                              context.go('/');
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Welcome to Adhinasth!")));
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setDialogState(() => isVerifying = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                    content: Text("Invalid Code"),
                                    backgroundColor: Colors.red));
                          }
                        }
                      },
                child: isVerifying
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text("VERIFY",
                        style: GoogleFonts.inter(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: ClayContainer(
                        height: 44,
                        width: 44,
                        borderRadius: 22,
                        color: theme.cardColor,
                        parentColor: theme.bgGradient.first,
                        emboss: false,
                        child: Icon(Icons.arrow_back_rounded,
                            color: theme.subTextColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text("Create Account",
                      style: GoogleFonts.inter(
                          fontSize: 30, // Clean size
                          fontWeight: FontWeight.w600, // Clean weight
                          color: theme.textColor)),
                  const SizedBox(height: 8),
                  Text("Sign up to start learning.",
                      style: GoogleFonts.inter(
                          color: theme.subTextColor, fontSize: 16)),
                  const SizedBox(height: 40),
                  _ClayTextField(
                      controller: _nameController,
                      hint: "Full Name",
                      icon: Icons.person_rounded,
                      theme: theme),
                  const SizedBox(height: 20),
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
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _isLoading ? null : _verifyCaptcha,
                    child: ClayContainer(
                      height: 56,
                      width: double.infinity,
                      borderRadius: 16,
                      color: theme.accentColor,
                      parentColor: theme.bgGradient.first,
                      emboss: _isLoading,
                      spread: 3,
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text("Sign Up",
                                style: GoogleFonts.inter(
                                    // Clean Font
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                      ),
                    ),
                  ),

                  // --- GOOGLE SIGN UP ---
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: theme.subTextColor.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("OR",
                            style: GoogleFonts.inter(
                                color: theme.subTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      Expanded(
                          child: Divider(
                              color: theme.subTextColor.withOpacity(0.2))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // ✅ REAL GOOGLE LOGO
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.public,
                                                color: Colors.blue),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Continue with Google",
                                    style: GoogleFonts.inter(
                                      // Clean Font
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
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: GoogleFonts.inter(color: theme.subTextColor),
                        children: [
                          TextSpan(
                              text: "Log In",
                              style: GoogleFonts.inter(
                                  color: theme.accentColor,
                                  fontWeight: FontWeight.bold))
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
          style: GoogleFonts.inter(
              color: theme.textColor,
              fontWeight: FontWeight.w600), // Clean Font
          decoration: InputDecoration(
            icon: Icon(icon, color: theme.subTextColor, size: 20),
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(color: theme.subTextColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
