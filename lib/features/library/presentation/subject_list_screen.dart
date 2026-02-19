import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../library_providers.dart';
import '../../../../core/theme/clay_kit.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/mesh_background.dart';

// --- PROVIDERS ---
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

class _SubjectListScreenState extends ConsumerState<SubjectListScreen> {
  // Removed GlowController as requested

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onDiceTap() async {
    if (mounted) context.push('/quiz/random');
  }

  Future<void> _launchInsta() async {
    const url = 'https://instagram.com/toped.official?igsh=bTgzb253a3ViOWho';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  Future<void> _launchYoutube() async {
    const url = 'https://youtube.com/@TopEd_AS';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
              // 1. HEADER (UPDATED: More Attractive & Full)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(_getGreeting(),
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: theme.subTextColor)),
                              const SizedBox(width: 6),
                              const Icon(Icons.wb_sunny_rounded,
                                  color: Colors.amber, size: 16),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(userName,
                              style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor,
                                  height: 1.0)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: ClayContainer(
                          height: 56,
                          width: 56,
                          borderRadius: 20,
                          color: theme.cardColor,
                          parentColor: theme.bgGradient.first,
                          emboss: false,
                          spread: 2,
                          child: Icon(Icons.person_rounded,
                              color: theme.accentColor, size: 28),
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
                              color: const Color(0xFFFFD700), // Gold
                              theme: theme,
                              prefix: "#",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BentoStatTile(
                              label: "Total XP",
                              valueAsync: scoreAsync,
                              icon: Icons.bolt_rounded,
                              color: const Color(0xFFFF9F1C), // Orange
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ROW B: Line of the Day + Tools
                      SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LINE OF THE DAY (UPDATED)
                            Expanded(
                              flex: 3,
                              child: dailyUpdateAsync.when(
                                loading: () => _LoadingContainer(theme: theme),
                                error: (_, __) => const SizedBox(),
                                data: (update) => _LineOfTheDayCard(
                                  text: update.factText,
                                  theme: theme,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Tools Column
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _GlassButton(
                                      onTap: () => context.push('/saved'),
                                      baseColor: const Color.fromARGB(
                                          255, 64, 179, 255),
                                      icon: Icons.bookmark_rounded,
                                      label: "Saved",
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: _AnimatedRubyDice(onTap: _onDiceTap),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. SUBJECTS HEADER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Row(
                    children: [
                      Text("Explore Subjects",
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor)),
                      const Spacer(),
                      Icon(Icons.grid_view_rounded,
                          color: theme.subTextColor.withOpacity(0.5), size: 20),
                    ],
                  ),
                ),
              ),

              // 4. PREMIUM SUBJECT GRID
              subjectsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, s) =>
                    SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
                data: (subjects) {
                  return SliverPadding(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final subject = subjects[index];
                        final style =
                            _getSubjectStyle(subject.id, subject.title);

                        return _PremiumSubjectCard(
                          subject: subject,
                          style: style,
                          theme: theme,
                          onTap: () => context.push('/chapters/${subject.id}'),
                        );
                      }, childCount: subjects.length),
                    ),
                  );
                },
              ),

              // 5. COMMUNITY SECTION
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Column(
                    children: [
                      Text("Join the TopEd Community",
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.subTextColor)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialButton(
                              icon: FontAwesomeIcons.instagram,
                              color: const Color(0xFFE1306C),
                              onTap: _launchInsta),
                          const SizedBox(width: 20),
                          _SocialButton(
                              icon: FontAwesomeIcons.youtube,
                              color: const Color(0xFFFF0000),
                              onTap: _launchYoutube),
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

  // --- 🎨 PREMIUM SUBJECT STYLING LOGIC ---
  _SubjectStyle _getSubjectStyle(int id, String title) {
    final t = title.toLowerCase();

    // 1. COMPUTER
    if (id == 1 || t.contains('computer')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.laptopCode,
        shadowColor: Colors.blueAccent,
      );
    }
    // 2. UP GK
    if (id == 2 || t.contains('up') || t.contains('uttar')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.landmarkDome,
        shadowColor: Colors.orange,
      );
    }
    // 3. HINDI
    if (id == 3 || t.contains('hindi')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFFEB3349), Color(0xFFF45C43)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.language,
        shadowColor: Colors.redAccent,
      );
    }
    // OTHER SUBJECTS
    if (t.contains('history')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFFD4A664), Color(0xFF8D6E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.scroll,
        shadowColor: Colors.brown,
      );
    }
    if (t.contains('geography')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.earthAmericas,
        shadowColor: Colors.blue,
      );
    }
    if (t.contains('polity') || t.contains('constitution')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.gavel,
        shadowColor: Colors.red[900]!,
      );
    }
    if (t.contains('economics') || t.contains('economy')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.chartLine,
        shadowColor: Colors.green,
      );
    }
    if (t.contains('science')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF833ab4), Color(0xFFfd1d1d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.flask,
        shadowColor: Colors.purple,
      );
    }
    if (t.contains('english')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFF667db6), Color(0xFF0082c8), Color(0xFF667db6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.a,
        shadowColor: Colors.indigo,
      );
    }
    if (t.contains('current affairs')) {
      return _SubjectStyle(
        gradient: const LinearGradient(
            colors: [Color(0xFFED213A), Color(0xFF93291E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        icon: FontAwesomeIcons.newspaper,
        shadowColor: Colors.red[800]!,
      );
    }

    return _SubjectStyle(
      gradient: const LinearGradient(
          colors: [Color(0xFF304352), Color(0xFFd7d2cc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      icon: FontAwesomeIcons.bookOpen,
      shadowColor: Colors.grey,
    );
  }
}

// --- 🎨 HELPER CLASSES & WIDGETS ---

class _SubjectStyle {
  final Gradient gradient;
  final IconData icon;
  final Color shadowColor;
  _SubjectStyle(
      {required this.gradient, required this.icon, required this.shadowColor});
}

// ✨ PREMIUM SUBJECT CARD
class _PremiumSubjectCard extends StatelessWidget {
  final dynamic subject;
  final _SubjectStyle style;
  final dynamic theme;
  final VoidCallback onTap;

  const _PremiumSubjectCard(
      {required this.subject,
      required this.style,
      required this.theme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: style.gradient,
          boxShadow: [
            BoxShadow(
              color: style.shadowColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 💧 Watermark Icon
              Positioned(
                right: -15,
                bottom: -15,
                child: Transform.rotate(
                  angle: -0.2,
                  child: FaIcon(
                    style.icon,
                    size: 90,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),

              // 📝 Content
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: FaIcon(style.icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      subject.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "Start Now",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.white.withOpacity(0.9))
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 📦 NEW: LINE OF THE DAY CARD (with Typing Animation)
class _LineOfTheDayCard extends StatelessWidget {
  final String text;
  final dynamic theme;

  const _LineOfTheDayCard({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Premium Indigo/Deep Purple Gradient
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF3C40C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(Icons.format_quote_rounded,
                size: 100, color: Colors.white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Text("LINE OF THE DAY",
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _TypingText(
                      text: text,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ⌨️ TYPING TEXT ANIMATION
class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TypingText({required this.text, required this.style});

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText += widget.text[_currentIndex];
            _currentIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}

// 📦 GLASS BUTTON
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color baseColor;
  final IconData icon;
  final String label;

  const _GlassButton({
    required this.onTap,
    required this.baseColor,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: baseColor.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4)),
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
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 26, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(label,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
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

// 📦 ANIMATED DICE
class _AnimatedRubyDice extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedRubyDice({required this.onTap});

  @override
  State<_AnimatedRubyDice> createState() => _AnimatedRubyDiceState();
}

class _AnimatedRubyDiceState extends State<_AnimatedRubyDice> {
  late Timer _timer;
  final List<IconData> _faces = [
    FontAwesomeIcons.diceOne,
    FontAwesomeIcons.diceTwo,
    FontAwesomeIcons.diceThree,
    FontAwesomeIcons.diceFour,
    FontAwesomeIcons.diceFive,
    FontAwesomeIcons.diceSix,
  ];
  int _currentFaceIndex = 4;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() => _currentFaceIndex = Random().nextInt(_faces.length));
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
        decoration: BoxDecoration(
          color: const Color(0xFFA30000),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 8),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF5350), Color(0xFFB71C1C), Color(0xFF5D0000)],
            stops: [0.1, 0.5, 0.9],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(_faces[_currentFaceIndex],
                    key: ValueKey<int>(_currentFaceIndex),
                    size: 26,
                    color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 4),
              Text("Quiz",
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// 📦 LOADING
class _LoadingContainer extends StatelessWidget {
  final dynamic theme;
  const _LoadingContainer({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// 📦 BENTO TILE
class _BentoStatTile extends StatelessWidget {
  final String label;
  final AsyncValue<dynamic> valueAsync;
  final IconData icon;
  final Color color;
  final dynamic theme;
  final String prefix;

  const _BentoStatTile(
      {required this.label,
      required this.valueAsync,
      required this.icon,
      required this.color,
      required this.theme,
      this.prefix = ""});

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
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.subTextColor,
                        fontWeight: FontWeight.w600)),
                valueAsync.when(
                  data: (val) => Text("$prefix$val",
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor)),
                  loading: () => SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.subTextColor)),
                  error: (_, __) => Text("-",
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 📦 SOCIAL BUTTON
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
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(child: FaIcon(icon, color: color, size: 24)),
      ),
    );
  }
}
