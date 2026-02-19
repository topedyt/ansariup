// ignore_for_file: unused_result, duplicate_ignore

import 'dart:async';
import 'dart:io';
import 'dart:ui'; // ✅ Required for High Quality Blur
import 'dart:math';
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
import 'package:url_launcher/url_launcher.dart';

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

  late ConfettiController _confettiController;

  final List<String> adminEmails = const [
    "ansarisalik25@gmail.com",
    "ansariplayer25@gmail.com"
  ];

  // 🔗 PAYMENT URL
  final String _paymentUrl =
      "https://up-special-ngfksp18y-topeds-projects-cf77eb10.vercel.app";

  bool get _isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && adminEmails.contains(user.email);
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
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

  // --- 🔒 DIALOGS ---
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
                "There are only $available free questions available. Please try starting a quiz with $available questions instead.",
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
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      if (controller.text.isNotEmpty) {
                        await ref
                            .read(supabaseClientProvider)
                            .from('questions')
                            .update({field: controller.text.trim()}).eq(
                                'id', questionId);
                        ref.refresh(smartQuestionsProvider(widget.chapterId));
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Updated!")));
                        }
                      }
                    },
                    child: const Text("Save")),
              ],
            ));
  }

  // --- ✨ HIGH QUALITY FEEDBACK CARDS ---
  void _showCenterFeedback(bool isCorrect) {
    final Color mainColor =
        isCorrect ? const Color(0xFF00E676) : const Color(0xFFFF1744);

    final List<Color> bgGradient = isCorrect
        ? [
            const Color(0xFF00C853).withOpacity(0.9),
            const Color(0xFF1B5E20).withOpacity(0.95)
          ]
        : [
            const Color(0xFFFF1744).withOpacity(0.9),
            const Color(0xFFB71C1C).withOpacity(0.95)
          ];

    final IconData icon =
        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final String text = isCorrect ? "Awesome!" : "Incorrect";

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 🛑 FIX: User cannot close this manually
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curvedValue = Curves.elasticOut.transform(anim.value);
        final scale = curvedValue.clamp(0.0, 1.2);

        Widget cardContent = Container(
          width: 260,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradient),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: mainColor.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 2,
                  offset: const Offset(0, 15))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                ]),
                child: Icon(icon, size: 70, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4)
                      ])),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Text(
                  isCorrect ? "+2.0 XP" : "-0.5 Penalty",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none),
                ),
              )
            ],
          ),
        );

        if (!kIsWeb) {
          cardContent = ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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

  // --- 🏏 HIGH QUALITY MILESTONE CARDS ---
  void _triggerCricketMilestone(int streak) {
    String title = "";
    String sub = "";
    List<Color> gradientColors = [];
    IconData icon = Icons.star;

    if (streak == 4) {
      title = "FOUR! 🏏";
      sub = "Boundary Hit!";
      gradientColors = [const Color(0xFF1B5E20), const Color(0xFF69F0AE)];
      icon = Icons.sports_cricket_rounded;
    } else if (streak == 6) {
      title = "SIXER! 🚀";
      sub = "Out of the Park!";
      gradientColors = [const Color(0xFF311B92), const Color(0xFFB388FF)];
      icon = Icons.rocket_launch_rounded;
    } else if (streak == 10) {
      title = "Power!";
      sub = "Unstoppable!";
      gradientColors = [const Color(0xFFB71C1C), const Color(0xFFFF8A80)];
      icon = Icons.sports_baseball_rounded;
    } else if (streak == 50) {
      title = "FIFTY! ⚔️";
      sub = "Half Century!";
      gradientColors = [const Color(0xFF0D47A1), const Color(0xFF82B1FF)];
      icon = Icons.shield_rounded;
    } else if (streak == 100) {
      title = "CENTURY! 👑";
      sub = "Legendary!";
      gradientColors = [const Color(0xFFFF6F00), const Color(0xFFFFE57F)];
      icon = Icons.emoji_events_rounded;
    } else {
      return;
    }

    _confettiController.play();

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 🛑 FIX: User cannot close this manually
      barrierLabel: "Milestone",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curvedValue = Curves.elasticOut.transform(anim.value);
        final scale = curvedValue.clamp(0.0, 1.2);

        Widget cardContent = Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientColors.first.withOpacity(0.95),
                  gradientColors.last.withOpacity(0.9)
                ]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                  color: gradientColors.first.withOpacity(0.6),
                  blurRadius: 50,
                  spreadRadius: 5)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 15,
                          offset: Offset(0, 5))
                    ]),
                child: Icon(icon, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 40,
                      fontWeight: FontWeight.w900, // Extra Bold
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      letterSpacing: 2,
                      shadows: [
                        const Shadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 4))
                      ])),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(sub.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ),
            ],
          ),
        );

        if (!kIsWeb) {
          cardContent = ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: cardContent,
            ),
          );
        }

        return Transform.scale(
          scale: scale,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: gradientColors.last.withOpacity(0.5),
                        blurRadius: 100,
                        spreadRadius: 30)
                  ]),
                ),
                cardContent,
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

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
        if ([4, 6, 10, 50, 100].contains(_streakCount)) {
          _triggerCricketMilestone(_streakCount);
        } else {
          _showCenterFeedback(true);
        }
      } else {
        _streakCount = 0;
        _showCenterFeedback(false);
      }
    });

    try {
      final points = isCorrect ? 2.0 : -0.5;
      await ref.read(supabaseClientProvider).rpc('update_career_points',
          params: {'delta': points, 'q_id': qId, 'correct': isCorrect});
    } catch (e) {
      debugPrint("Error updating score: $e");
    }
  }

  // --- 🏗️ BUILD METHOD ---
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

                        // 🔴 SAFEGUARD: END OF QUIZ CHECK
                        if (_currentIndex >= questions.length) {
                          return _buildEndOfQuizState(questions,
                              totalCountAsync, isPro, isTestMode, theme);
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
                                  // 🏆 LOGO & BRANDING
                                  Row(children: [
                                    Image.asset('assets/icons/icon.png',
                                        height: 28),
                                    const SizedBox(width: 10),
                                    Text("UP Special by Toped",
                                        style: GoogleFonts.inter(
                                            color: theme.textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                  if (isTestMode)
                                    ClayContainer(
                                        height: 40,
                                        borderRadius: 20,
                                        color: _secondsRemaining < 60
                                            ? Colors.redAccent.withOpacity(0.1)
                                            : theme.cardColor,
                                        emboss: true,
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
                                                      color: _secondsRemaining <
                                                              60
                                                          ? Colors.red
                                                          : theme.textColor))
                                            ])))
                                  else
                                    const SizedBox(width: 44),
                                ],
                              ),
                            ),

                            // PROGRESS
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(children: [
                                ClayContainer(
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
                                                    BorderRadius.circular(
                                                        5))))),
                                const SizedBox(height: 6),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        "Question ${_currentIndex + 1} of $displayTotal",
                                        style: TextStyle(
                                            color: theme.subTextColor,
                                            fontSize: 11)))
                              ]),
                            ),
                            const SizedBox(height: 16),

                            // SCROLLABLE CONTENT
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
                                    // Question Text
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

                                    // Options
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

                                    // Explanation
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
                                    // Toolbar
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
                                                          : theme
                                                              .subTextColor)),
                                              onPressed: () {
                                                ref.read(
                                                        toggleBookmarkProvider)(
                                                    question.id, isBookmarked);
                                                ref.refresh(
                                                    isBookmarkedProvider(
                                                        question.id));
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

                            // FOOTER NAV
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Row(
                                children: [
                                  // 🔒 DISABLED BACK BUTTON to prevent XP Farming Loophole
                                  Opacity(
                                    opacity:
                                        0.5, // Visually indicates disabled state
                                    child: ClayContainer(
                                        height: 56,
                                        width: 56,
                                        borderRadius: 16,
                                        color: theme.cardColor,
                                        emboss: false,
                                        child: Icon(Icons.arrow_back_rounded,
                                            color: theme.subTextColor)),
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

  // --- 🟥 END OF QUIZ BUILDER ---
  Widget _buildEndOfQuizState(
      List<dynamic> questions,
      AsyncValue<int> totalCountAsync,
      bool isPro,
      bool isTestMode,
      dynamic theme) {
    if (totalCountAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final trueTotal = totalCountAsync.value ?? questions.length;
    final hiddenQuestions = trueTotal - questions.length;

    // A. SHOW PAYWALL
    if (hiddenQuestions > 0 && !isPro && !isTestMode) {
      return _buildPaywallView(theme, hiddenQuestions);
    }

    // B. FINISH QUIZ (Auto-Submit)
    if (!_isSubmitted && !isTestMode) {
      Future.microtask(() => _submitTest(questions));
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildPaywallView(dynamic theme, int lockedCount) {
    return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, size: 60, color: theme.accentColor),
          const SizedBox(height: 20),
          Text("Chapter Limit Reached",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor)),
          const SizedBox(height: 12),
          Text(
              "You have finished the free questions.\nUnlock $lockedCount more questions in this chapter with Pro.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.subTextColor, fontSize: 16, height: 1.5)),
          const SizedBox(height: 40),
          QuizUpsellCard(
              theme: theme, lockedCount: lockedCount, paymentUrl: _paymentUrl),
          const SizedBox(height: 30),
          TextButton(
              onPressed: () => context.pop(),
              child: Text("Maybe Later",
                  style: TextStyle(color: theme.subTextColor)))
        ]));
  }

  // --- HELPERS (Share, Report, Result, OptionItem, Upsell, Stars) ---
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

  // --- 📸 2.0 HIGH QUALITY SCREENSHOT GENERATOR (Glassbox Style) ---
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
                width: 500, // Fixed width
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2E3192),
                      Color(0xFF00D4FF)
                    ], // Deep Blue -> Cyan
                  ),
                ),
                child: Stack(
                  children: [
                    // 💧 WATERMARK IN BACKGROUND
                    Positioned.fill(
                      child: Center(
                        child: Opacity(
                          opacity: 0.1,
                          child: Image.asset('assets/icons/icon.png',
                              width: 300), // Watermark
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🏆 Branding Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Image.asset('assets/icons/icon.png',
                                    height: 32),
                              ),
                              const SizedBox(width: 14),
                              Text("UP Special",
                                  style: GoogleFonts.inter(
                                      // ✅ Inter Font
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // 🃏 THE GLASSBOX CONTAINER
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.9), // Milky Glass
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white,
                                  width: 2), // Frost Border
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10))
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Question Text
                                Text(
                                  question.questionText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 18, // ⚡ Updated: Same size as options
                                    fontWeight: FontWeight.w400, // ⚡ Updated: No Bold
                                    color: const Color(0xFF2D3436),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Divider(
                                    height: 1, color: Colors.black12),
                                const SizedBox(height: 24),

                                // Options List
                                _buildShareOption("A", question.optionA),
                                _buildShareOption("B", question.optionB),
                                _buildShareOption("C", question.optionC),
                                _buildShareOption("D", question.optionD),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // 📢 Footer / Call to Action
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.download_rounded,
                                    color: Colors.amber, size: 22),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    "Download UP Special by Toped",
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 150),
        pixelRatio: 3.0, // ⚡ 3.0x Quality (Crisp Text)
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
              '${directory.path}/adhinasth_share_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await imagePath.writeAsBytes(imageBytes);
      await Share.shareXFiles([XFile(imagePath.path)],
          text: 'Can you solve this? 🧠 Download the app for UP Exam Prep!');
    } catch (e) {
      debugPrint("Share Error: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // --- STYLIZED OPTION FOR SCREENSHOT ---
  Widget _buildShareOption(String label, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA), // Light grey fill
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF2E3192).withOpacity(0.1),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    );
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

// ✅ DARK MODE FIX FOR OPTIONS
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color baseColor = theme.cardColor;
    Color iconColor = theme.subTextColor.withOpacity(0.1);
    Color textColor = theme.textColor;
    bool isPressed = false;

    if (state == _OptionState.correct) {
      // ✅ Dark Mode: Dark Green | Light Mode: Light Green
      baseColor = isDark
          ? const Color(0xFF1B5E20).withOpacity(0.5)
          : const Color(0xFFE8F5E9);
      iconColor = isDark ? Colors.greenAccent : Colors.green;
      textColor = isDark ? Colors.greenAccent : Colors.green[900]!;
    } else if (state == _OptionState.wrong) {
      // ✅ Dark Mode: Dark Red | Light Mode: Light Red
      baseColor = isDark
          ? const Color(0xFFB71C1C).withOpacity(0.5)
          : const Color(0xFFFFEBEE);
      iconColor = isDark ? Colors.redAccent : Colors.red;
      textColor = isDark ? Colors.redAccent : Colors.red[900]!;
    } else if (state == _OptionState.selected) {
      isPressed = true;
      baseColor = theme.cardColor;
      iconColor = Colors.blue;
      textColor = isDark ? Colors.blueAccent : Colors.blue[900]!;
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
                                            ? (isDark
                                                ? Colors.blueAccent
                                                : Colors.blue)
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
  final String paymentUrl;
  const QuizUpsellCard(
      {super.key,
      required this.theme,
      this.lockedCount = 20,
      required this.paymentUrl});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () async {
          if (!await launchUrl(Uri.parse(paymentUrl),
              mode: LaunchMode.externalApplication)) {}
        },
        child: ClayContainer(
            width: double.infinity,
            borderRadius: 24,
            color: const Color(0xFF212121),
            parentColor: theme.bgGradient.first,
            emboss: false,
            spread: 4,
            child: Stack(children: [
              Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 120, color: Colors.amber.withOpacity(0.1))),
              Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(children: [
                    Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Colors.amber, Colors.orange]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: const Icon(Icons.diamond_rounded,
                            color: Colors.white, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text("Unlock Pro Access",
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text("Click to unlock all questions instantly.",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8)))
                        ])),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white54, size: 16)
                  ]))
            ])));
  }
}