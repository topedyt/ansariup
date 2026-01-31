// ignore_for_file: unused_result, duplicate_ignore

import 'dart:async';
import 'dart:io';
import 'dart:ui'; // For blur
import 'dart:math'; // For confetti star shape
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';

import '../library_providers.dart';
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

// --- PROVIDERS ---
final chapterTitleProvider =
    FutureProvider.family<String, int>((ref, chapterId) async {
  final supabase = ref.read(supabaseClientProvider);
  final data = await supabase
      .from('chapters')
      .select('title')
      .eq('id', chapterId)
      .single();
  return data['title'] as String;
});

final totalQuestionCountProvider =
    FutureProvider.family<int, int>((ref, chapterId) async {
  final supabase = ref.read(supabaseClientProvider);
  return await supabase
      .rpc('get_total_question_count', params: {'cid': chapterId});
});

final isUserProProvider = FutureProvider<bool>((ref) async {
  final user = ref.read(supabaseClientProvider).auth.currentUser;
  if (user == null) return false;
  final data = await ref
      .read(supabaseClientProvider)
      .from('users')
      .select('is_pro')
      .eq('id', user.id)
      .single();
  return data['is_pro'] ?? false;
});

class QuizScreen extends ConsumerStatefulWidget {
  final int chapterId;
  final String mode;
  final int questionCount;

  const QuizScreen({
    super.key,
    required this.chapterId,
    this.mode = 'practice',
    this.questionCount = 10,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;

  // --- STATE ---
  bool _isAnswered = false;
  String? _selectedOption;
  bool _showExplanation = false;
  final Map<int, String> _testAnswers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isSubmitted = false;

  int _streakCount = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  // ✨ CONFETTI CONTROLLER
  late ConfettiController _confettiController;

  // 👑 ADMIN LOGIC
  final List<String> adminEmails = const [
    "ansarisalik25@gmail.com",
    "ansariplayer25@gmail.com"
  ];

  bool get _isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && adminEmails.contains(user.email);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
        duration: const Duration(seconds: 1)); // Init Confetti

    if (widget.mode == 'test') {
      _secondsRemaining = widget.questionCount * 45;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _submitTest();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _refreshStats() {
    ref.refresh(userScoreProvider);
    ref.refresh(userRankProvider);
  }

  // --- 🔒 TEST MODE LIMIT DIALOG ---
  void _showTestLimitDialog(
      BuildContext context, int available, int requested) {
    final theme = ref.read(appThemeProvider);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                const Icon(Icons.lock_clock_rounded, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text("Limit Reached",
                    style: TextStyle(
                        color: theme.textColor, fontWeight: FontWeight.bold)),
              ]),
              content: Text(
                "There are only $available free questions available, so a $requested question quiz can't be started.\n\nPlease try starting a quiz with $available questions instead.",
                style: TextStyle(color: theme.subTextColor, fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                  child: const Text("OK",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ));
  }

  // --- 👑 ADMIN EDIT DIALOG ---
  void _showEditDialog(int questionId, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final theme = ref.read(appThemeProvider);

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: theme.cardColor,
              title:
                  Text("Edit $field", style: TextStyle(color: theme.textColor)),
              content: TextField(
                controller: controller,
                maxLines: null,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  hintText: "Enter new text...",
                  hintStyle: TextStyle(color: theme.subTextColor),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.subTextColor)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      final newValue = controller.text.trim();
                      if (newValue.isNotEmpty) {
                        await ref
                            .read(supabaseClientProvider)
                            .from('questions')
                            .update({field: newValue}).eq('id', questionId);

                        // ignore: unused_result
                        ref.refresh(smartQuestionsProvider(widget.chapterId));
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Updated!")));
                        }
                      }
                    },
                    child: const Text("Save",
                        style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold))),
              ],
            ));
  }

  // --- ✨ REFACTORED: GLASSMORPHIC FEEDBACK (Correct/Wrong) ---
  void _showCenterFeedback(bool isCorrect) {
    // Colors
    final Color mainColor =
        isCorrect ? const Color(0xFF00C853) : const Color(0xFFFF1744);
    final Color bgGradientStart =
        isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2);
    final Color bgGradientEnd = isCorrect
        ? Colors.green.withOpacity(0.05)
        : Colors.red.withOpacity(0.05);
    final IconData icon =
        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final String text = isCorrect ? "Awesome!" : "Incorrect";

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        // Elastic pop animation
        final curvedValue = Curves.elasticOut.transform(anim.value);
        final scale = curvedValue.clamp(0.0, 1.2);

        // 1. Define Glass Card Content
        Widget cardContent = Container(
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: kIsWeb
                  ? [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.8)
                    ] // Web Fallback
                  : [bgGradientStart, bgGradientEnd], // Mobile Glass
            ),
            borderRadius: BorderRadius.circular(30),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: mainColor.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Icon
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: mainColor.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2)
                ]),
                child: Icon(icon, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                text,
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isCorrect ? "+2.0 XP" : "-0.5 Penalty",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              )
            ],
          ),
        );

        // 2. Apply Blur (Mobile Only)
        if (!kIsWeb) {
          cardContent = ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: cardContent,
            ),
          );
        }

        return Transform.scale(
          scale: scale,
          child: FadeTransition(
            opacity: anim,
            child: Center(child: cardContent),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  // --- 🏏 REFACTORED: MILESTONE CELEBRATION ---
  void _triggerCricketMilestone(int streak) {
    String title = "";
    String sub = "";
    List<Color> gradientColors = [];
    IconData icon = Icons.star;

    if (streak == 4) {
      title = "FOUR! 🏏";
      sub = "Boundary Hit!";
      gradientColors = [const Color(0xFF4CAF50), const Color(0xFF00E676)];
      icon = Icons.sports_cricket_rounded;
    } else if (streak == 6) {
      title = "SIXER! 🚀";
      sub = "Out of the Park!";
      gradientColors = [const Color(0xFF673AB7), const Color(0xFFB388FF)];
      icon = Icons.rocket_launch_rounded;
    } else if (streak == 10) {
      title = "WICKET! ☝️";
      sub = "Unstoppable!";
      gradientColors = [const Color(0xFFD50000), const Color(0xFFFF5252)];
      icon = Icons.sports_baseball_rounded;
    } else if (streak == 50) {
      title = "FIFTY! ⚔️";
      sub = "Half Century!";
      gradientColors = [const Color(0xFF0D47A1), const Color(0xFF42A5F5)];
      icon = Icons.shield_rounded;
    } else if (streak == 100) {
      title = "CENTURY! 👑";
      sub = "Legendary!";
      gradientColors = [const Color(0xFFFF6F00), const Color(0xFFFFD700)];
      icon = Icons.emoji_events_rounded;
    } else {
      return;
    }

    _confettiController.play();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Milestone",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curvedValue = Curves.elasticOut.transform(anim.value) - 1.0;
        final scale = 1.0 + curvedValue;

        // Glass Card
        Widget cardContent = Container(
          width: 300,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: kIsWeb
                  ? [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.8)
                    ]
                  : [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.1)
                    ],
            ),
            borderRadius: BorderRadius.circular(30),
            border:
                Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: anim.value * 0.2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: gradientColors.first.withOpacity(0.6),
                            blurRadius: 30,
                            offset: const Offset(0, 8))
                      ],
                      border: Border.all(color: Colors.white, width: 4)),
                  child: Icon(icon, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        const Shadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4))
                      ])),
              const SizedBox(height: 10),
              Text(sub.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ],
          ),
        );

        if (!kIsWeb) {
          cardContent = ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: cardContent,
            ),
          );
        }

        return Transform.scale(
          scale: scale.clamp(0.0, 1.5),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: gradientColors.last.withOpacity(0.5),
                        blurRadius: 80,
                        spreadRadius: 20)
                  ]),
                ),
                cardContent,
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  // --- LOGIC: HANDLE TAP (Fixing Overlap Issue) ---
  Future<void> _handleOptionTap(
      int qId, String opt, String correct, bool isTest) async {
    if (isTest) {
      if (_isSubmitted) return;
      setState(() {
        if (_testAnswers[qId] == opt) {
          _testAnswers.remove(qId);
        } else {
          _testAnswers[qId] = opt;
        }
      });
      return;
    }

    if (_isAnswered) return;

    final isCorrect = (opt == correct);
    setState(() {
      _selectedOption = opt;
      _isAnswered = true;
      _showExplanation = true;

      if (isCorrect) {
        _streakCount++;
        // 🚀 LOGIC FIX: If milestone hit, ONLY show milestone. Else show normal feedback.
        if ([4, 6, 10, 50, 100].contains(_streakCount)) {
          _triggerCricketMilestone(_streakCount);
        } else {
          if (mounted) _showCenterFeedback(true);
        }
      } else {
        _streakCount = 0;
        if (mounted) _showCenterFeedback(false);
      }
    });

    final points = isCorrect ? 2.0 : -0.5;
    try {
      await ref.read(supabaseClientProvider).rpc('update_career_points',
          params: {'delta': points, 'q_id': qId, 'correct': isCorrect});
    } catch (e) {
      // Error handling
    }
  }

  // ... [BUILD METHOD & OTHER HELPERS REMAIN STANDARD BUT INCLUDED BELOW] ...

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(smartQuestionsProvider(widget.chapterId));
    final titleAsync = ref.watch(chapterTitleProvider(widget.chapterId));
    final isProAsync = ref.watch(isUserProProvider);
    final totalCountAsync =
        ref.watch(totalQuestionCountProvider(widget.chapterId));
    final theme = ref.watch(appThemeProvider);
    final isTestMode = widget.mode == 'test';

    return Scaffold(
      body: Stack(
        children: [
          // 1. CONTENT LAYER
          MeshBackground(
            theme: theme,
            child: SafeArea(
              child: isProAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: $e")),
                  data: (isPro) {
                    return questionsAsync.when(
                      loading: () => Center(
                          child: CircularProgressIndicator(
                              color: theme.accentColor)),
                      error: (err, stack) => Center(child: Text("Error: $err")),
                      data: (allQuestions) {
                        if (isTestMode &&
                            !isPro &&
                            widget.questionCount > allQuestions.length) {
                          Future.microtask(() {
                            if (mounted)
                              _showTestLimitDialog(context, allQuestions.length,
                                  widget.questionCount);
                          });
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final questions = isTestMode
                            ? allQuestions.take(widget.questionCount).toList()
                            : allQuestions;
                        if (questions.isEmpty)
                          return const Center(
                              child: Text("No questions found."));

                        if (_currentIndex >= questions.length) {
                          final trueTotal =
                              totalCountAsync.value ?? questions.length;
                          final hiddenQuestions = trueTotal - questions.length;
                          if (hiddenQuestions > 0 && !isPro && !isTestMode) {
                            return _buildPaywallView(theme, hiddenQuestions);
                          }
                          if (!_isSubmitted && !isTestMode) {
                            Future.microtask(() => _submitTest(questions));
                          }
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final question = questions[_currentIndex];
                        final displayTotal = questions.length;
                        final progress = (_currentIndex + 1) / displayTotal;
                        final isBookmarkedAsync =
                            ref.watch(isBookmarkedProvider(question.id));
                        final isBookmarked = isBookmarkedAsync.value ?? false;

                        return Column(
                          children: [
                            // HEADER
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _refreshStats();
                                      if (isTestMode && !_isSubmitted)
                                        _showExitDialog(context);
                                      else
                                        context.pop();
                                    },
                                    child: ClayContainer(
                                        height: 44,
                                        width: 44,
                                        borderRadius: 22,
                                        color: theme.cardColor,
                                        emboss: false,
                                        spread: 2,
                                        child: Icon(Icons.close_rounded,
                                            color: theme.subTextColor,
                                            size: 20)),
                                  ),
                                  if (isTestMode)
                                    ClayContainer(
                                        height: 40,
                                        borderRadius: 20,
                                        color: _secondsRemaining < 60
                                            ? Colors.redAccent.withOpacity(0.1)
                                            : theme.cardColor,
                                        emboss: true,
                                        spread: 2,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Row(children: [
                                              Icon(Icons.timer_outlined,
                                                  size: 18,
                                                  color: _secondsRemaining < 60
                                                      ? Colors.red
                                                      : theme.accentColor),
                                              const SizedBox(width: 8),
                                              Text(
                                                  _formatTime(
                                                      _secondsRemaining),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          _secondsRemaining < 60
                                                              ? Colors.red
                                                              : theme.textColor,
                                                      fontFamily: 'monospace'))
                                            ])))
                                  else
                                    Expanded(
                                        child: Column(children: [
                                      titleAsync.when(
                                          data: (t) => Text(t,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.textColor),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          loading: () => const SizedBox(),
                                          error: (_, __) => const SizedBox()),
                                      Text(
                                          "Q ${_currentIndex + 1} / $displayTotal",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme.subTextColor))
                                    ])),
                                  const SizedBox(width: 44),
                                ],
                              ),
                            ),

                            // PROGRESS
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: ClayContainer(
                                  height: 10,
                                  width: double.infinity,
                                  borderRadius: 5,
                                  color: theme.cardColor,
                                  emboss: true,
                                  child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              color: isTestMode
                                                  ? Colors.orangeAccent
                                                  : theme.accentColor,
                                              borderRadius:
                                                  BorderRadius.circular(5))))),
                            ),
                            const SizedBox(height: 24),

                            // CONTENT
                            Expanded(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  children: [
                                    if (question.pyqYear != null) ...[
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                              color: theme.accentColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: theme.accentColor
                                                      .withOpacity(0.3))),
                                          child: Text(
                                              "PYQ: ${question.pyqYear}",
                                              style: TextStyle(
                                                  color: theme.accentColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12))),
                                      const SizedBox(height: 16)
                                    ],
                                    Stack(children: [
                                      ClayContainer(
                                          width: double.infinity,
                                          borderRadius: 24,
                                          color: theme.cardColor,
                                          emboss: false,
                                          spread: 4,
                                          child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Text(question.questionText,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme.textColor,
                                                      height: 1.4)))),
                                      if (_isAdmin)
                                        Positioned(
                                            top: 0,
                                            right: 0,
                                            child: IconButton(
                                                icon: const Icon(
                                                    Icons.edit_rounded,
                                                    color: Colors.blueAccent,
                                                    size: 20),
                                                onPressed: () =>
                                                    _showEditDialog(
                                                        question.id,
                                                        'question_text',
                                                        question
                                                            .questionText))),
                                    ]),
                                    const SizedBox(height: 32),
                                    ...["A", "B", "C", "D"].map((optLabel) {
                                      String optText = "";
                                      String dbField = "";
                                      if (optLabel == "A") {
                                        optText = question.optionA;
                                        dbField = 'option_a';
                                      }
                                      if (optLabel == "B") {
                                        optText = question.optionB;
                                        dbField = 'option_b';
                                      }
                                      if (optLabel == "C") {
                                        optText = question.optionC;
                                        dbField = 'option_c';
                                      }
                                      if (optLabel == "D") {
                                        optText = question.optionD;
                                        dbField = 'option_d';
                                      }

                                      _OptionState state = _OptionState.neutral;
                                      if (isTestMode) {
                                        if (_testAnswers[question.id] ==
                                            optLabel)
                                          state = _OptionState.selected;
                                      } else {
                                        state = _getPracticeState(
                                            optLabel, question.correctOption);
                                      }

                                      return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          child: _OptionItem(
                                              label: optLabel,
                                              text: optText,
                                              state: state,
                                              theme: theme,
                                              onTap: () => _handleOptionTap(
                                                  question.id,
                                                  optLabel,
                                                  question.correctOption,
                                                  isTestMode),
                                              onEdit: _isAdmin
                                                  ? () => _showEditDialog(
                                                      question.id,
                                                      dbField,
                                                      optText)
                                                  : null));
                                    }),
                                    if (!isTestMode &&
                                        _isAnswered &&
                                        _showExplanation)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 16, bottom: 24),
                                        child: Stack(children: [
                                          ClayContainer(
                                              width: double.infinity,
                                              borderRadius: 16,
                                              color: theme.cardColor,
                                              emboss: true,
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(children: [
                                                          Icon(
                                                              Icons
                                                                  .lightbulb_rounded,
                                                              color: theme
                                                                  .accentColor,
                                                              size: 20),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text("Explanation",
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: theme
                                                                      .accentColor))
                                                        ]),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            question.explanation ??
                                                                "No explanation available.",
                                                            style: TextStyle(
                                                                color: theme
                                                                    .textColor,
                                                                height: 1.4))
                                                      ]))),
                                          if (_isAdmin)
                                            Positioned(
                                                top: 0,
                                                right: 0,
                                                child: IconButton(
                                                    icon: const Icon(
                                                        Icons.edit_rounded,
                                                        color:
                                                            Colors.blueAccent,
                                                        size: 18),
                                                    onPressed: () =>
                                                        _showEditDialog(
                                                            question.id,
                                                            'explanation',
                                                            question.explanation ??
                                                                "")))
                                        ]),
                                      ),
                                    const SizedBox(height: 16),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          TextButton.icon(
                                              icon: Icon(
                                                  isBookmarked
                                                      ? Icons.bookmark_rounded
                                                      : Icons
                                                          .bookmark_border_rounded,
                                                  size: 20,
                                                  color: isBookmarked
                                                      ? Colors.orange
                                                      : theme.subTextColor),
                                              label: Text(
                                                  isBookmarked
                                                      ? "Saved"
                                                      : "Save",
                                                  style: TextStyle(
                                                      color: isBookmarked
                                                          ? Colors.orange
                                                          : theme.subTextColor,
                                                      fontWeight: isBookmarked
                                                          ? FontWeight.bold
                                                          : FontWeight.normal)),
                                              onPressed: () {
                                                ref.read(
                                                        toggleBookmarkProvider)(
                                                    question.id, isBookmarked);
                                                ref.refresh(
                                                    isBookmarkedProvider(
                                                        question.id));
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(isBookmarked
                                                            ? "Bookmark Removed"
                                                            : "Bookmark Saved"),
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    600)));
                                              }),
                                          Container(
                                              height: 16,
                                              width: 1,
                                              color: theme.subTextColor
                                                  .withOpacity(0.3),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12)),
                                          TextButton.icon(
                                              icon: _isSharing
                                                  ? const SizedBox(
                                                      height: 16,
                                                      width: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))
                                                  : const Icon(
                                                      Icons.share_rounded,
                                                      size: 20),
                                              label: Text("Share",
                                                  style: TextStyle(
                                                      color: theme.textColor)),
                                              onPressed: _isSharing
                                                  ? null
                                                  : () => _shareQuestionImage(
                                                      question, theme)),
                                          Container(
                                              height: 16,
                                              width: 1,
                                              color: theme.subTextColor
                                                  .withOpacity(0.3),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12)),
                                          TextButton.icon(
                                              icon: const Icon(
                                                  Icons.flag_rounded,
                                                  size: 20),
                                              label: const Text("Report"),
                                              style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      theme.subTextColor),
                                              onPressed: () =>
                                                  _showReportDialog(context,
                                                      question.id, theme))
                                        ]),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),

                            // FOOTER
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: _currentIndex > 0
                                        ? () {
                                            setState(() {
                                              _currentIndex--;
                                              if (!isTestMode) {
                                                _isAnswered = false;
                                                _selectedOption = null;
                                                _showExplanation = false;
                                              }
                                            });
                                          }
                                        : null,
                                    child: ClayContainer(
                                        height: 56,
                                        width: 56,
                                        borderRadius: 16,
                                        color: _currentIndex > 0
                                            ? theme.cardColor
                                            : theme.cardColor.withOpacity(0.5),
                                        emboss: false,
                                        child: Icon(Icons.arrow_back_rounded,
                                            color: _currentIndex > 0
                                                ? theme.textColor
                                                : theme.subTextColor)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: ClayContainer(
                                          height: 56,
                                          width: double.infinity,
                                          borderRadius: 16,
                                          color: isTestMode
                                              ? Colors.orange
                                              : theme.accentColor,
                                          emboss: false,
                                          spread: 4,
                                          onTap: () {
                                            if (_currentIndex <
                                                questions.length - 1) {
                                              setState(() {
                                                _currentIndex++;
                                                if (!isTestMode) {
                                                  _isAnswered = false;
                                                  _selectedOption = null;
                                                  _showExplanation = false;
                                                }
                                              });
                                            } else {
                                              if (isTestMode) {
                                                _submitTest(questions);
                                              } else {
                                                setState(() {
                                                  _currentIndex++;
                                                });
                                              }
                                            }
                                          },
                                          child: Center(
                                              child: Text(
                                                  _currentIndex <
                                                          questions.length - 1
                                                      ? "NEXT QUESTION"
                                                      : (isTestMode
                                                          ? "SUBMIT TEST"
                                                          : "FINISH"),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1))))),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }),
            ),
          ),

          // 2. CONFETTI LAYER (Always Top)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
                createParticlePath: drawStar,
                gravity: 0.2,
                numberOfParticles: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS (Share, Report, Paywall, Result, OptionItem, Upsell, Stars) ---
  // (Standard helper methods kept from previous version for brevity)

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  Future<void> _shareQuestionImage(dynamic question, dynamic theme) async {
    setState(() => _isSharing = true);
    try {
      final Uint8List imageBytes =
          await _screenshotController.captureFromWidget(
              MediaQuery(
                  data: const MediaQueryData(),
                  child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      home: Material(
                          child: Container(
                              color: const Color(0xFFFAFAFA),
                              padding: const EdgeInsets.all(32),
                              width: 400,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF6C63FF),
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: const Text("Adhinasth App",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)))),
                                    const SizedBox(height: 32),
                                    Text(question.questionText,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            fontFamily: 'sans-serif')),
                                    const SizedBox(height: 40),
                                    _buildShareOption("A", question.optionA),
                                    _buildShareOption("B", question.optionB),
                                    _buildShareOption("C", question.optionC),
                                    _buildShareOption("D", question.optionD)
                                  ]))))),
              delay: const Duration(milliseconds: 150),
              pixelRatio: 2.0);
      final directory = await getTemporaryDirectory();
      final imagePath = await File(
              '${directory.path}/adhinasth_share_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await imagePath.writeAsBytes(imageBytes);
      await Share.shareXFiles([XFile(imagePath.path)],
          text: 'Can you solve this?');
    } catch (e) {
      debugPrint("Share Error: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error generating image: $e")));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildShareOption(String label, String text) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          Text("$label.",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)))
        ]));
  }

  void _showReportDialog(BuildContext context, int qId, dynamic theme) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: theme.cardColor,
                title: Text("Report Issue",
                    style: TextStyle(color: theme.textColor)),
                content: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: "What's wrong?"),
                    maxLines: 3),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          ref.read(reportQuestionProvider)(
                              qId, controller.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Report Sent.")));
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text("Submit",
                          style: TextStyle(color: Colors.redAccent)))
                ]));
  }

  void _submitTest([List<dynamic>? questions]) {
    if (_isSubmitted) return;
    _timer?.cancel();
    setState(() => _isSubmitted = true);
    List<dynamic> finalList = questions ?? [];
    if (questions == null) {
      final questionsAsync = ref.read(smartQuestionsProvider(widget.chapterId));
      if (questionsAsync.asData != null)
        finalList = widget.mode == 'test'
            ? questionsAsync.asData!.value.take(widget.questionCount).toList()
            : questionsAsync.asData!.value;
    }
    int correct = 0;
    int wrong = 0;
    int skipped = 0;
    for (var q in finalList) {
      String? userAns = _testAnswers[q.id];
      if (userAns == null)
        skipped++;
      else if (userAns == q.correctOption)
        correct++;
      else
        wrong++;
    }
    double finalScore = (correct * 2.0) - (wrong * 0.5);
    final theme = ref.read(appThemeProvider);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
                backgroundColor: theme.cardColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text("Test Result",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: theme.textColor)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 4)),
                      child: Center(
                          child: Text(finalScore.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor)))),
                  const SizedBox(height: 20),
                  ScoreRow(
                      label: "Correct", value: "$correct", color: Colors.green),
                  ScoreRow(label: "Wrong", value: "$wrong", color: Colors.red),
                  ScoreRow(
                      label: "Skipped", value: "$skipped", color: Colors.grey),
                  const Divider(),
                  Text(
                      "Accuracy: ${((correct / (correct + wrong > 0 ? correct + wrong : 1)) * 100).toInt()}%",
                      style: TextStyle(color: theme.subTextColor))
                ]),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _refreshStats();
                        Navigator.pop(context);
                      },
                      child: const Text("Done"))
                ]));
  }

  void _showExitDialog(BuildContext context) {
    final theme = ref.read(appThemeProvider);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: theme.cardColor,
                title: Text("Quit Test?",
                    style: TextStyle(color: theme.textColor)),
                content: Text("Progress will be lost.",
                    style: TextStyle(color: theme.subTextColor)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        Navigator.pop(ctx);
                        _refreshStats();
                        Navigator.pop(context);
                      },
                      child: const Text("Quit",
                          style: TextStyle(color: Colors.red)))
                ]));
  }

  _OptionState _getPracticeState(String opt, String correct) {
    if (!_isAnswered)
      return _selectedOption == opt
          ? _OptionState.selected
          : _OptionState.neutral;
    if (opt == correct) return _OptionState.correct;
    if (_selectedOption == opt && opt != correct) return _OptionState.wrong;
    return _OptionState.neutral;
  }

  Widget _buildPaywallView(dynamic theme, int lockedCount) {
    return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Free Questions Finished",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor)),
          const SizedBox(height: 12),
          Text(
              "There are more $lockedCount questions in this chapter. To attempt all questions with full explanations, buy pass for just ₹99.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.subTextColor, fontSize: 16, height: 1.5)),
          const SizedBox(height: 40),
          QuizUpsellCard(theme: theme, lockedCount: lockedCount),
          const SizedBox(height: 30),
          TextButton(
              onPressed: () => context.pop(),
              child: Text("Go Back to Home",
                  style: TextStyle(color: theme.subTextColor)))
        ]));
  }
}

class ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const ScoreRow(
      {super.key,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]));
  }
}

enum _OptionState { neutral, selected, correct, wrong }

class _OptionItem extends StatelessWidget {
  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;
  final dynamic theme;
  final VoidCallback? onEdit;
  const _OptionItem(
      {required this.label,
      required this.text,
      required this.state,
      required this.onTap,
      required this.theme,
      this.onEdit});
  @override
  Widget build(BuildContext context) {
    Color baseColor = theme.cardColor;
    Color iconColor = theme.subTextColor.withOpacity(0.1);
    Color textColor = theme.textColor;
    bool isPressed = false;
    if (state == _OptionState.correct) {
      baseColor = const Color(0xFFE8F5E9);
      iconColor = Colors.green;
      textColor = Colors.green[900]!;
    } else if (state == _OptionState.wrong) {
      baseColor = const Color(0xFFFFEBEE);
      iconColor = Colors.red;
      textColor = Colors.red[900]!;
    } else if (state == _OptionState.selected) {
      isPressed = true;
      baseColor = theme.cardColor;
      iconColor = Colors.blue;
      textColor = Colors.blue[900]!;
    }
    return GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          ClayContainer(
              width: double.infinity,
              borderRadius: 16,
              color: baseColor,
              parentColor: theme.bgGradient.first,
              emboss: isPressed,
              spread: isPressed ? 2 : 4,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: iconColor, shape: BoxShape.circle),
                            child: state == _OptionState.correct ||
                                    state == _OptionState.wrong
                                ? Icon(
                                    state == _OptionState.correct
                                        ? Icons.check
                                        : Icons.close,
                                    color: Colors.white,
                                    size: 18)
                                : Text(label,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: state == _OptionState.selected
                                            ? Colors.blue
                                            : theme.subTextColor))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Text(text,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    height: 1.3)))
                      ]))),
          if (onEdit != null)
            Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: Colors.blueGrey),
                    onPressed: onEdit))
        ]));
  }
}

class QuizUpsellCard extends StatelessWidget {
  final dynamic theme;
  final int lockedCount;
  const QuizUpsellCard({super.key, required this.theme, this.lockedCount = 20});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => context.push('/subscription'),
        child: ClayContainer(
            width: double.infinity,
            borderRadius: 24,
            color: const Color(0xFF2D3436),
            parentColor: theme.bgGradient.first,
            emboss: false,
            spread: 4,
            child: Stack(children: [
              Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(Icons.lock_outline_rounded,
                      size: 120, color: Colors.white.withOpacity(0.05))),
              Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(children: [
                    Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.amber, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text("Unlock More Questions",
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                              "Upgrade to Pro to unlock $lockedCount more questions.",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7)))
                        ]))
                  ]))
            ])));
  }
}
