// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 1. PROVIDER: Fetch only 'pending' requests
final pendingPaymentsProvider = FutureProvider.autoDispose((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('payment_requests')
      .select()
      .eq('status', 'pending')
      .order('created_at', ascending: false);
});

// 2. PROVIDER: Generate Secure Link (Signed URL)
final secureImageProvider =
    FutureProvider.family.autoDispose<String, String>((ref, path) async {
  return await Supabase.instance.client.storage
      .from('payment_proofs')
      .createSignedUrl(path, 60);
});

class PaymentAdminScreen extends ConsumerStatefulWidget {
  const PaymentAdminScreen({super.key});

  @override
  ConsumerState<PaymentAdminScreen> createState() => _PaymentAdminScreenState();
}

class _PaymentAdminScreenState extends ConsumerState<PaymentAdminScreen> {
  bool _isUploadingQr = false;
  final ImagePicker _picker = ImagePicker();

  // --- QR UPLOAD LOGIC ---
  Future<void> _updateQrCode(String planName, String dbKey) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingQr = true);

    try {
      final file = File(image.path);
      final fileName = 'qr_codes/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Upload to Storage
      await Supabase.instance.client.storage
          .from('app-assets')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      // 2. Get Public URL
      final publicUrl = Supabase.instance.client.storage
          .from('app-assets')
          .getPublicUrl(fileName);

      // 3. Update Database Config
      await Supabase.instance.client
          .from('app_config')
          .upsert({'id': dbKey, 'value': publicUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$planName QR Updated Successfully!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploadingQr = false);
    }
  }

  void _showQrManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update QR Codes",
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isUploadingQr)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildQrOption("Monthly Plan (₹49)", "qr_monthly", Colors.blue),
              _buildQrOption(
                  "Half-Yearly Plan (₹99)", "qr_half_yearly", Colors.orange),
              _buildQrOption("Yearly Plan (₹149)", "qr_yearly", Colors.green),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildQrOption(String title, String key, Color color) {
    return ListTile(
      leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.qr_code, color: color)),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.upload_file, color: Colors.grey),
      onTap: () {
        Navigator.pop(context); // Close sheet
        _updateQrCode(title, key);
      },
    );
  }

  // --- REJECT LOGIC ---
  Future<void> _rejectUser(int reqId) async {
    try {
      await Supabase.instance.client
          .from('payment_requests')
          .update({'status': 'rejected'}) // Mark as rejected
          .eq('id', reqId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Request Rejected ❌"),
            backgroundColor: Colors.orange));
        ref.refresh(pendingPaymentsProvider); // Remove from list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- NEW: APPROVE LOGIC WITH CHOICE DIALOG ---
  Future<void> _showApprovalDialog(
      int reqId, String currentPlan, String email) async {
    // Default to the user's requested plan
    String selectedPlan = currentPlan;

    // Normalize plan name just in case
    if (!['Monthly', 'Half Yearly', 'Yearly'].contains(selectedPlan)) {
      if (selectedPlan.contains('Yearly')) {
        selectedPlan = 'Yearly';
      } else if (selectedPlan.contains('Half')) {
        selectedPlan = 'Half Yearly';
      } else {
        selectedPlan = 'Monthly';
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Approve Subscription"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("User: $email",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              const Text("Select Duration to Grant:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Plan Selection Chips
              Wrap(
                spacing: 8,
                children: ['Monthly', 'Half Yearly', 'Yearly'].map((plan) {
                  final isSelected = selectedPlan == plan;
                  return ChoiceChip(
                    label: Text(plan),
                    selected: isSelected,
                    selectedColor: Colors.green.withOpacity(0.2),
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.green[800] : Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (bool selected) {
                      if (selected) {
                        setDialogState(() => selectedPlan = plan);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                await _processApproval(reqId, selectedPlan);
              },
              child: const Text("CONFIRM & APPROVE"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processApproval(int reqId, String finalPlan) async {
    try {
      // Update plan_selected (in case admin changed it) AND status
      // The DB Trigger will detect 'status'='approved' and use 'plan_selected'
      // to calculate expiry date.
      await Supabase.instance.client.from('payment_requests').update(
          {'plan_selected': finalPlan, 'status': 'approved'}).eq('id', reqId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Approved as $finalPlan! ✅"),
            backgroundColor: Colors.green));
        ref.refresh(pendingPaymentsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(pendingPaymentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Verifications",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // THE QR MANAGER BUTTON
          IconButton(
            onPressed: _showQrManager,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Manage QR Codes",
          )
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 60, color: Colors.green),
                  const SizedBox(height: 16),
                  Text("All caught up!",
                      style:
                          GoogleFonts.inter(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final req = requests[index];
              final email = req['user_email'] ?? 'Unknown Email';
              final reqId = req['id'];
              final imagePath = req['screenshot_path'];

              // Fetch the plan name from DB (or default to Unknown)
              final planName = req['plan_selected'] ?? 'Unknown Plan';

              // Parse date safely
              DateTime date;
              try {
                date = DateTime.parse(req['created_at']).toLocal();
              } catch (e) {
                date = DateTime.now();
              }

              // Determine visual color based on plan
              Color planColor = Colors.blue;
              if (planName.toString().contains('Yearly')) {
                planColor = Colors.green;
              }
              if (planName.toString().contains('Half')) {
                planColor = Colors.orange;
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Email + Plan Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email,
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(DateFormat('dd MMM, hh:mm a').format(date),
                                    style: GoogleFonts.inter(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: planColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: planColor.withOpacity(0.3))),
                            child: Text(planName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: planColor,
                                    fontSize: 12)),
                          )
                        ],
                      ),

                      const Divider(height: 24),
                      Text("Payment Proof:",
                          style: GoogleFonts.inter(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),

                      // Secure Image Preview
                      Consumer(builder: (ctx, ref, _) {
                        if (imagePath == null || imagePath.isEmpty) {
                          return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image));
                        }

                        final imageAsync =
                            ref.watch(secureImageProvider(imagePath));
                        return imageAsync.when(
                          loading: () => Container(
                              height: 200,
                              color: Colors.grey[100],
                              child: const Center(
                                  child: CircularProgressIndicator())),
                          error: (_, __) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image)),
                          data: (signedUrl) => GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                      child: Image.network(signedUrl))),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(signedUrl,
                                  height: 250,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rejectUser(reqId),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: const Text("REJECT"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              // CHANGED: Opens Dialog instead of instant approve
                              onPressed: () =>
                                  _showApprovalDialog(reqId, planName, email),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const Text("APPROVE"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
