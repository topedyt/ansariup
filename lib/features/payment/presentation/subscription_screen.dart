// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/clay_kit.dart';
import '../../../../core/theme/mesh_background.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  // ✅ LOGIC: If on Web, show Payment UI. If on Mobile, show Link.
  bool get _showPaymentUi => kIsWeb;

  // 🔗 REPLACE THIS with your actual Vercel link
  final String _websiteUrl =
      "https://up-special-j68ktnypb-topeds-projects-cf77eb10.vercel.app";

  bool _isUploading = false;
  bool _isLoadingData = true;

  // Web Safe Image Handling
  Uint8List? _imageBytes;

  // Data Containers
  Map<String, String> _qrUrls = {
    'qr_monthly': '',
    'qr_half_yearly': '',
    'qr_yearly': '',
  };

  String _currentUpiId = "Loading...";
  final ImagePicker _picker = ImagePicker();

  // Plan Selection Logic
  int _selectedPlanIndex = 2; // Default to Yearly

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Monthly',
      'price': '₹49',
      'duration': '1 Month',
      'db_key': 'qr_monthly',
      'color': Colors.blueAccent
    },
    {
      'title': 'Half Yearly',
      'price': '₹99',
      'duration': '6 Months',
      'db_key': 'qr_half_yearly',
      'color': Colors.orangeAccent
    },
    {
      'title': 'Yearly',
      'price': '₹149',
      'duration': '1 Year',
      'db_key': 'qr_yearly',
      'color': Colors.green
    },
  ];

  // 🆕 DYNAMIC ADMIN CHECK
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // We check admin status immediately
    _checkAdminStatus();

    if (_showPaymentUi) {
      _fetchPaymentDetails();
    }
  }

  // 🆕 Step 1: Check Database for Admin Email
  Future<void> _checkAdminStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email == null) return;

    try {
      final response = await Supabase.instance.client
          .from('admin_users')
          .select()
          .eq('email', user!.email!)
          .maybeSingle(); // Returns null if not found, instead of throwing error

      if (mounted) {
        setState(() {
          _isAdmin = response != null; // True if email exists in table
        });
      }
    } catch (e) {
      debugPrint("Admin check failed: $e");
    }
  }

  Future<void> _fetchPaymentDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select('id, value')
          .inFilter('id',
              ['qr_monthly', 'qr_half_yearly', 'qr_yearly', 'upi_id_text']);

      if (mounted) {
        setState(() {
          for (var row in response) {
            final id = row['id'];
            final val = row['value'];

            if (id == 'upi_id_text') {
              _currentUpiId = val;
            } else {
              _qrUrls[id] = val;
            }
          }
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ... (Keep _pickImage, _submitPaymentRequest, _adminUpdateQrCode exactly the same) ...
  // ✅ UNIVERSAL IMAGE PICKER
  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submitPaymentRequest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please Login First")));
      return;
    }
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select an image")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('payment_proofs')
          .uploadBinary(fileName, _imageBytes!);

      await Supabase.instance.client.from('payment_requests').insert({
        'user_id': user.id,
        'user_email': user.email,
        'screenshot_path': fileName,
        'status': 'pending',
        'plan_selected': _plans[_selectedPlanIndex]['title'],
      });

      if (mounted) _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _adminUpdateQrCode() async {
    if (!_isAdmin) return;
    await _pickImage();
    if (_imageBytes == null) return;

    setState(() => _isUploading = true);
    try {
      final fileName = 'qr_codes/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage.from('app-assets').uploadBinary(
          fileName, _imageBytes!,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('app-assets')
          .getPublicUrl(fileName);

      final currentKey = _plans[_selectedPlanIndex]['db_key'];

      await Supabase.instance.client
          .from('app_config')
          .upsert({'id': currentKey, 'value': publicUrl});

      await _fetchPaymentDetails();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("${_plans[_selectedPlanIndex]['title']} QR Updated!")));
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Request Submitted"),
        content: const Text("Please return to the App and wait for approval."),
        actions: [
          TextButton(onPressed: () => context.go('/'), child: const Text("OK"))
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ... (Keep Header UI) ...
                    Text("Unlock Pro Access",
                        style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor)),
                    const SizedBox(height: 10),
                    if (!_showPaymentUi)
                      Text("Choose a plan that suits you best",
                          style: GoogleFonts.inter(color: theme.subTextColor)),

                    const SizedBox(height: 30),

                    // 📱 MOBILE VIEW
                    if (!_showPaymentUi) ...[
                      // 1. Plan Cards
                      ...List.generate(_plans.length, (index) {
                        final plan = _plans[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ClayContainer(
                            width: double.infinity,
                            height: 80,
                            borderRadius: 16,
                            color: theme.cardColor,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(plan['title'],
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: theme.textColor)),
                                      Text(plan['duration'],
                                          style: GoogleFonts.inter(
                                              color: theme.subTextColor,
                                              fontSize: 12)),
                                    ],
                                  ),
                                  Text(plan['price'],
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                          color: plan['color'])),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 30),
                      // 2. Button
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(_websiteUrl)),
                        child: ClayContainer(
                          width: double.infinity,
                          height: 60,
                          borderRadius: 16,
                          color: theme.accentColor,
                          parentColor: theme.bgGradient.first,
                          child: Center(
                            child: Text("PROCEED TO PAYMENT",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          "You will be redirected to our secure payment portal",
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.subTextColor.withOpacity(0.6))),
                    ],

                    // 💻 WEB VIEW
                    if (_showPaymentUi) ...[
                      // 1. Plan Tabs
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25)),
                        child: Row(
                          children: List.generate(_plans.length, (index) {
                            final isSelected = _selectedPlanIndex == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPlanIndex = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.accentColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(25)),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _plans[index]['title'],
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : theme.subTextColor),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 30),
                      Text(_plans[_selectedPlanIndex]['price'],
                          style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor)),
                      Text("for ${_plans[_selectedPlanIndex]['duration']}",
                          style: GoogleFonts.inter(color: theme.subTextColor)),

                      const SizedBox(height: 30),

                      // QR Code
                      _isLoadingData
                          ? const CircularProgressIndicator()
                          : Container(
                              height: 220,
                              width: 220,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 2)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.network(
                                  _qrUrls[_plans[_selectedPlanIndex]
                                          ['db_key']] ??
                                      '',
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, _) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_2,
                                          size: 50, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text("No QR Set",
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: Colors.grey))
                                    ],
                                  ),
                                ),
                              ),
                            ),

                      // 🔒 ADMIN EDIT BUTTON (Now uses _isAdmin variable)
                      if (_isAdmin)
                        TextButton.icon(
                            onPressed: _adminUpdateQrCode,
                            icon: const Icon(Icons.edit),
                            label: Text(
                                "Edit ${_plans[_selectedPlanIndex]['title']} QR")),

                      const SizedBox(height: 20),
                      SelectableText(_currentUpiId,
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor)),

                      const SizedBox(height: 30),

                      // Upload Area
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: theme.cardColor.withOpacity(0.5),
                              border: Border.all(
                                  color: theme.subTextColor.withOpacity(0.3),
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(12)),
                          child: _imageBytes == null
                              ? Center(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                      Icon(Icons.upload_file,
                                          color: theme.accentColor, size: 30),
                                      const SizedBox(height: 8),
                                      Text("Upload Payment Screenshot",
                                          style: GoogleFonts.inter(
                                              color: theme.subTextColor))
                                    ]))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.memory(_imageBytes!,
                                      fit: BoxFit.cover)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            onPressed:
                                _isUploading ? null : _submitPaymentRequest,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: _isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("SUBMIT PAYMENT")),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
