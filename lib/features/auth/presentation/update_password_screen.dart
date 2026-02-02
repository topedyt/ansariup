import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password cannot be empty")),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 SUPABASE MAGIC:
      // This updates the user's password. Since they clicked the email link,
      // Supabase has already created a temporary authenticated session for them.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D3436),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Success!",
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text("Your password has been updated successfully.",
                style: GoogleFonts.inter(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.go('/'); // Navigate to Home
                },
                child: Text("Go Home",
                    style: GoogleFonts.inter(
                        color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error: ${e.toString().replaceAll("AuthException:", "").trim()}"),
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
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  ClayContainer(
                    height: 80,
                    width: 80,
                    borderRadius: 40,
                    color: theme.cardColor,
                    parentColor: theme.bgGradient.first,
                    emboss: false,
                    child: Icon(Icons.lock_reset_rounded,
                        size: 36, color: theme.accentColor),
                  ),

                  const SizedBox(height: 30),

                  // Header
                  Text("New Password",
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor)),
                  const SizedBox(height: 10),
                  Text("Enter your new secure password below.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: theme.subTextColor, fontSize: 15)),

                  const SizedBox(height: 40),

                  // Input Field
                  ClayContainer(
                    height: 56,
                    borderRadius: 16,
                    color: theme.cardColor,
                    parentColor: theme.bgGradient.first,
                    emboss: true,
                    spread: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: GoogleFonts.inter(
                            color: theme.textColor,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "New Password",
                          hintStyle: GoogleFonts.inter(
                              color: theme.subTextColor.withOpacity(0.5)),
                          icon: Icon(Icons.lock_rounded,
                              color: theme.subTextColor, size: 20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Update Button
                  GestureDetector(
                    onTap: _isLoading ? null : _updatePassword,
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
                            : Text("Update Password",
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
