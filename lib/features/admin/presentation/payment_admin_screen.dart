// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
// This asks Supabase: "Give me a link to this private image that works for only 60 seconds"
final secureImageProvider =
    FutureProvider.family.autoDispose<String, String>((ref, path) async {
  return await Supabase.instance.client.storage
      .from('payment_proofs')
      .createSignedUrl(path, 60);
});

class PaymentAdminScreen extends ConsumerWidget {
  const PaymentAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingPaymentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Verifications"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text("No pending payments! 🎉"));
          }

          return ListView.builder(
            itemCount: requests.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final req = requests[index];
              final email = req['user_email'] ?? 'Unknown Email';
              final userId = req['user_id'];
              final reqId = req['id'];
              final imagePath = req['screenshot_path']; // "user_id/123.jpg"
              final date = DateTime.parse(req['created_at']).toLocal();

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Info
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Requested: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const Divider(height: 24),

                      // Secure Image Preview
                      Text("Payment Proof:",
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      Consumer(builder: (ctx, ref, _) {
                        final imageAsync =
                            ref.watch(secureImageProvider(imagePath));
                        return imageAsync.when(
                          loading: () => const SizedBox(
                              height: 200,
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (_, __) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.red))),
                          data: (signedUrl) => GestureDetector(
                            onTap: () =>
                                _showFullScreenImage(context, signedUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                signedUrl,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Add reject logic later if needed
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Reject logic not implemented yet")));
                              },
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text("Reject"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _approveUser(context, ref, reqId, userId),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white),
                              icon: const Icon(Icons.check_circle, size: 18),
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

  Future<void> _approveUser(
      BuildContext context, WidgetRef ref, int reqId, String userId) async {
    try {
      // Calling the SECURE function
      await Supabase.instance.client.rpc('approve_payment_secure', params: {
        'request_id': reqId,
        'target_user_id': userId,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("User Upgraded Successfully! ✅"),
          backgroundColor: Colors.green));

      // Refresh the list to remove the approved item
      await ref.refresh(pendingPaymentsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Approval Failed: $e"), backgroundColor: Colors.red));
    }
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}
