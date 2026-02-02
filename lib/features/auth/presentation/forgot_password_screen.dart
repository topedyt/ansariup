import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 SUPABASE MAGIC: Sends the reset email
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo:
            'io.supabase.flutter://reset-callback', // Match this with Supabase Dashboard
      );

      if (mounted) {
        // Show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D3436),
            title: Text("Check your Email",
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              "We have sent a password reset link to $email.\n\nClick the link in the email to set a new password.",
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back to Login
                },
                child: Text("OK",
                    style: GoogleFonts.inter(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back Button
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

                  // Header
                  Text("Forgot Password?",
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor)),
                  const SizedBox(height: 10),
                  Text(
                    "Don't worry! It happens. Please enter the email associated with your account.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: theme.subTextColor, fontSize: 15),
                  ),
                  const SizedBox(height: 40),

                  // Email Input
                  _ClayTextField(
                    controller: _emailController,
                    hint: "Enter your email",
                    icon: Icons.email_rounded,
                    theme: theme,
                  ),
                  const SizedBox(height: 30),

                  // Send Button
                  GestureDetector(
                    onTap: _isLoading ? null : _sendResetLink,
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
                            : Text("Send Code",
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
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

  const _ClayTextField(
      {required this.controller,
      required this.hint,
      required this.icon,
      required this.theme});

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
          style: GoogleFonts.inter(
              color: theme.textColor, fontWeight: FontWeight.w600),
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
