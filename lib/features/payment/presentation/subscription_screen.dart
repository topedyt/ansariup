// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/clay_kit.dart';
import '../../../../core/theme/mesh_background.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isUploading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // 📝 CONFIG: Change these to your actual details
  final String _upiId = "9876543210@upi"; 
  final String _adminName = "Adhinasth Academy";
  
  // 📸 TODO: Replace this URL with the link to your actual QR Code image 
  // (You can upload your QR code to Supabase Storage and paste the public link here)
  final String _qrCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=9876543210@upi&pn=Adhinasth"; 

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitPaymentRequest() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please attach the payment screenshot")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Image to PRIVATE Bucket
      // Path format: "USER_ID/TIMESTAMP.jpg" 
      // This matches the RLS policy: (storage.foldername(name))[1] = auth.uid()
      final fileExt = _selectedImage!.path.split('.').last;
      final filePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('payment_proofs')
          .upload(filePath, _selectedImage!);

      // 2. Save Request to Database
      // Note: We save 'screenshot_path', NOT a public URL, because the bucket is private.
      await Supabase.instance.client.from('payment_requests').insert({
        'user_id': user.id,
        'user_email': user.email, // Saved for easier reading in Admin Panel
        'screenshot_path': filePath,
        'status': 'pending',
      });

      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3436),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Expanded(child: Text("Request Submitted", style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: const Text(
          "We have received your payment screenshot. \n\nYour account will be upgraded to PRO within 2-4 hours after verification.", 
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.go('/'); // Go Home
            },
            child: const Text("OK, Got it", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    
    return Scaffold(
      body: MeshBackground(
        theme: theme,
        child: SafeArea(
          child: Column(
            children: [
              // 1. HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: ClayContainer(
                        height: 40, width: 40, borderRadius: 20,
                        color: theme.cardColor, parentColor: theme.bgGradient.first,
                        child: Icon(Icons.arrow_back, color: theme.subTextColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text("Unlock Pro Access", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // 2. QR CODE SECTION
                      ClayContainer(
                        width: double.infinity,
                        borderRadius: 24,
                        color: theme.cardColor,
                        spread: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text("Step 1: Scan & Pay", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor)),
                              const SizedBox(height: 8),
                              Text("Pay ₹99 using any UPI App", style: TextStyle(color: theme.subTextColor, fontSize: 14)),
                              const SizedBox(height: 20),
                              
                              // QR IMAGE
                              Container(
                                height: 180, width: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300)
                                ),
                                child: Image.network(_qrCodeUrl, fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, _) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                ), 
                              ),
                              const SizedBox(height: 20),
                              
                              // UPI ID COPY
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.accentColor.withOpacity(0.3))
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_upiId, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: _upiId));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI ID Copied!")));
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 16, color: Colors.blueAccent),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Name: $_adminName", style: TextStyle(fontSize: 12, color: theme.subTextColor)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 3. UPLOAD SECTION
                      ClayContainer(
                        width: double.infinity,
                        borderRadius: 24,
                        color: theme.cardColor,
                        spread: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Step 2: Upload Screenshot", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor)),
                              const SizedBox(height: 8),
                              Text("Attach the payment success screenshot here.", style: TextStyle(color: theme.subTextColor, fontSize: 14)),
                              const SizedBox(height: 20),

                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 150, width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme.bgGradient.first.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.subTextColor.withOpacity(0.2), style: BorderStyle.solid),
                                  ),
                                  alignment: Alignment.center,
                                  child: _selectedImage == null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_rounded, size: 40, color: theme.accentColor),
                                            const SizedBox(height: 8),
                                            Text("Tap to select image", style: TextStyle(color: theme.subTextColor)),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.file(_selectedImage!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 4. SUBMIT BUTTON
                      GestureDetector(
                        onTap: _isUploading ? null : _submitPaymentRequest,
                        child: ClayContainer(
                          width: double.infinity, height: 60, borderRadius: 20,
                          color: _selectedImage == null ? Colors.grey : theme.accentColor,
                          parentColor: theme.bgGradient.first,
                          emboss: _isUploading,
                          child: Center(
                            child: _isUploading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text("SUBMIT REQUEST", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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