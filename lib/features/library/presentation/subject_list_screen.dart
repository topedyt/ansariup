import 'dart:async'; // For Timer
import 'dart:ui';
import 'dart:math'; // For Random
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ✅ Ensure this is added

import '../library_providers.dart';
import '../../../../core/theme/clay_kit.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/mesh_background.dart';

final isUserProProvider = FutureProvider<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  final data = await Supabase.instance.client
      .from('users')
      .select('is_pro')
      .eq('id', user.id)
      .single();
  return data['is_pro'] ?? false;
});

class SubjectListScreen extends ConsumerStatefulWidget {
  const SubjectListScreen({super.key});

  @override
  ConsumerState<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends ConsumerState<SubjectListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _onDiceTap() async {
    if (mounted) {
      context.push('/quiz/random');
    }
  }

  // 🔗 SOCIAL LINKS
  Future<void> _launchInsta() async {
    const url = 'https://instagram.com/toped.official?igsh=bTgzb253a3ViOWho';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  Future<void> _launchYoutube() async {
    const url = 'https://youtube.com/@TopEd_AS';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final dailyUpdateAsync = ref.watch(dailyUpdateProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final theme = ref.watch(appThemeProvider);
    final scoreAsync = ref.watch(userScoreProvider);
    final rankAsync = ref.watch(userRankProvider);

    final userName = Supabase
            .instance.client.auth.currentUser?.userMetadata?['full_name']
            ?.split(' ')[0] ??
        "Friend";

    return Scaffold(
      body: MeshBackground(
        theme: theme,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. HEADER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Hello, $userName",
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textColor)), // Simplified Font
                          const SizedBox(height: 4),
                          Text("Let's Start Learning...",
                              style: TextStyle(
                                  color: theme.subTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: ClayContainer(
                          height: 52,
                          width: 52,
                          borderRadius: 26,
                          color: theme.cardColor,
                          parentColor: theme.bgGradient.first,
                          emboss: false,
                          child: Icon(Icons.person_rounded,
                              color: theme.accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. BENTO DASHBOARD
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // ROW A: Stats
                      Row(
                        children: [
                          Expanded(
                            child: _BentoStatTile(
                              label: "Global Rank",
                              valueAsync: rankAsync,
                              icon: Icons.emoji_events_rounded,
                              color: Colors.amber,
                              prefix: "",
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BentoStatTile(
                              label: "Total XP",
                              valueAsync: scoreAsync,
                              icon: Icons.local_fire_department_rounded,
                              color: Colors.orange,
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ROW B: Wisdom + Buttons
                      SizedBox(
                        height: 170,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- DAILY WISDOM ---
                            Expanded(
                              child: dailyUpdateAsync.when(
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (_, __) => const SizedBox(),
                                data: (update) => ClayContainer(
                                  borderRadius: 24,
                                  color: const Color(0xFF2D3436),
                                  parentColor: theme.bgGradient.first,
                                  emboss: false,
                                  spread: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      children: [
                                        // Glow Bulb
                                        Positioned(
                                          right: -25,
                                          bottom: -25,
                                          child: AnimatedBuilder(
                                              animation: _glowAnimation,
                                              builder: (context, child) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color
                                                                .fromARGB(255,
                                                                236, 250, 255)
                                                            .withOpacity(0.3 *
                                                                _glowAnimation
                                                                    .value),
                                                        blurRadius: 50 *
                                                            _glowAnimation
                                                                .value,
                                                        spreadRadius: 10,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                      Icons.lightbulb_rounded,
                                                      size: 110,
                                                      color: Colors.white
                                                          .withOpacity(0.1)),
                                                );
                                              }),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.lightbulb_rounded,
                                                      color: Color.fromARGB(
                                                          255, 217, 241, 255),
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  Text("DAILY WISDOM",
                                                      style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(0.7),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  child: Text(
                                                    update.factText,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1.4),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // --- ACTION BUTTONS COLUMN ---
                            Column(
                              children: [
                                // 1. SAVED BUTTON (Theme Glass)
                                Expanded(
                                  child: _GlassButton(
                                    onTap: () => context.push('/saved'),
                                    baseColor:
                                        theme.accentColor, // Matches app theme
                                    icon: Icons.bookmark_rounded,
                                    iconSize: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 2. ANIMATED RUBY DICE (Changing Faces)
                                Expanded(
                                  child: _AnimatedRubyDice(onTap: _onDiceTap),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. SUBJECTS TITLE
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Text("Subjects",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor)),
                ),
              ),

              // 4. SUBJECTS GRID
              subjectsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, s) =>
                    SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
                data: (subjects) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final subject = subjects[index];
                      final colorInfo = _getSubjectColor(subject.id);
                      final iconData = _getSubjectIcon(subject.id);

                      return GestureDetector(
                        onTap: () => context.push('/chapters/${subject.id}'),
                        child: ClayContainer(
                          borderRadius: 24,
                          color: theme.cardColor,
                          parentColor: theme.bgGradient.last,
                          emboss: false,
                          spread: 4,
                          child: Stack(
                            children: [
                              Positioned(
                                right: -15,
                                bottom: -15,
                                child: Opacity(
                                  opacity: 0.05,
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Icon(iconData,
                                        size: 100, color: colorInfo.text),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 42,
                                      width: 42,
                                      decoration: BoxDecoration(
                                        color: colorInfo.color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(iconData,
                                          color: colorInfo.text, size: 24),
                                    ),
                                    const Spacer(),
                                    Text(subject.title,
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: theme.textColor,
                                            height: 1.1),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text("Start",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: theme.subTextColor)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 14, color: theme.subTextColor)
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: subjects.length),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 5. SOCIAL MEDIA FOOTER (Updated Text + FontAwesome)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      Text(
                        "Join the Community", // Simple, professional text
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.subTextColor),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialButton(
                            icon: FontAwesomeIcons.instagram, // Real Brand Icon
                            color: const Color(0xFFE1306C), // Insta Color
                            onTap: _launchInsta,
                          ),
                          const SizedBox(width: 20),
                          _SocialButton(
                            icon: FontAwesomeIcons.youtube, // Real Brand Icon
                            color: const Color(0xFFFF0000), // YouTube Color
                            onTap: _launchYoutube,
                          ),
                        ],
                      ),
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

  // --- LOGIC ---
  IconData _getSubjectIcon(int id) {
    switch (id) {
      case 1:
        return Icons.computer_rounded;
      case 2:
        return Icons.fort_rounded;
      case 3:
        return Icons.eco_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  _ColorSet _getSubjectColor(int id) {
    switch (id) {
      case 1:
        return _ColorSet(const Color(0xFFB3E5FC), const Color(0xFF81D4FA),
            const Color(0xFF0277BD));
      case 2:
        return _ColorSet(const Color(0xFFFFE0B2), const Color(0xFFFFCC80),
            const Color(0xFFEF6C00));
      case 3:
        return _ColorSet(const Color(0xFFC8E6C9), const Color(0xFFA5D6A7),
            const Color(0xFF2E7D32));
      default:
        return _ColorSet(
            const Color(0xFFF5F5F5), const Color(0xFFE0E0E0), Colors.black87);
    }
  }
}

// --- 🎲 NEW: ANIMATED RUBY DICE WIDGET ---
class _AnimatedRubyDice extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedRubyDice({required this.onTap});

  @override
  State<_AnimatedRubyDice> createState() => _AnimatedRubyDiceState();
}

class _AnimatedRubyDiceState extends State<_AnimatedRubyDice> {
  late Timer _timer;
  // List of FontAwesome Dice faces
  final List<IconData> _faces = [
    FontAwesomeIcons.diceOne,
    FontAwesomeIcons.diceTwo,
    FontAwesomeIcons.diceThree,
    FontAwesomeIcons.diceFour,
    FontAwesomeIcons.diceFive,
    FontAwesomeIcons.diceSix,
  ];
  int _currentFaceIndex = 4; // Start with 5

  @override
  void initState() {
    super.initState();
    // Change face every 2 seconds to make it look alive but not crazy
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentFaceIndex = Random().nextInt(_faces.length);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 77,
        decoration: BoxDecoration(
          color: const Color(0xFFA30000), // Deep Ruby Red Base
          borderRadius: BorderRadius.circular(20),
          // 1. Drop Shadow
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
          // 2. 3D Gradient (Simulates Inner Shadow/Depth)
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEF5350), // Highlight (Top Left)
              Color(0xFFB71C1C), // Mid
              Color(0xFF5D0000), // Shadow (Bottom Right)
            ],
            stops: [0.1, 0.5, 0.9],
          ),
          // 3. Shiny Edge
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Center(
          // Animated Switcher for smooth transition between numbers
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(_faces[_currentFaceIndex],
                key: ValueKey<int>(_currentFaceIndex),
                size: 32,
                color: Colors.white.withOpacity(0.9)),
          ),
        ),
      ),
    );
  }
}

// --- GLASS BUTTON (THEME MATCHED) ---
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color baseColor;
  final IconData icon;
  final double iconSize;

  const _GlassButton({
    required this.onTap,
    required this.baseColor,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 77,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor.withOpacity(0.8),
                        baseColor.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: iconSize, color: Colors.white),
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

// --- SOCIAL BUTTON (FONT AWESOME) ---
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50, width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Center(
            child: FaIcon(icon,
                color: color, size: 24)), // Use FaIcon for FontAwesome
      ),
    );
  }
}

// Stats Helper (Bento Tile)
class _BentoStatTile extends StatelessWidget {
  final String label;
  final AsyncValue<dynamic> valueAsync;
  final IconData icon;
  final Color color;
  final dynamic theme;
  final String prefix;
  final String suffix;

  const _BentoStatTile({
    required this.label,
    required this.valueAsync,
    required this.icon,
    required this.color,
    required this.theme,
    this.prefix = "",
    // ignore: unused_element_parameter
    this.suffix = "",
  });

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      height: 90,
      borderRadius: 24,
      color: theme.cardColor,
      parentColor: theme.bgGradient.first,
      emboss: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.subTextColor,
                          fontWeight: FontWeight.bold)),
                  valueAsync.when(
                    data: (val) {
                      return Text("$prefix$val$suffix",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor));
                    },
                    loading: () => SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: theme.subTextColor)),
                    error: (_, __) => Text("-",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor)),
                  ),
                ]),
          ],
        ),
      ),
    );
  }
}

class _ColorSet {
  final Color color;
  final Color shadow;
  final Color text;
  _ColorSet(this.color, this.shadow, this.text);
}
