import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../library_providers.dart';
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class SavedQuestionsScreen extends ConsumerWidget {
  const SavedQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final savedAsync = ref.watch(savedQuestionsProvider);

    return Scaffold(
      body: MeshBackground(
        theme: theme,
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: ClayContainer(
                        height: 44, width: 44, borderRadius: 22,
                        color: theme.cardColor, emboss: false,
                        child: Icon(Icons.arrow_back_rounded, color: theme.textColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text("Saved Questions", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.textColor)),
                  ],
                ),
              ),

              // LIST
              Expanded(
                child: savedAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: theme.accentColor)),
                  error: (e,s) => const Center(child: Text("Error loading saved items")),
                  data: (questions) {
                    if (questions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded, size: 64, color: theme.subTextColor.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text("No saved questions yet.", style: TextStyle(color: theme.subTextColor)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        return _SavedQuestionCard(question: questions[index], theme: theme);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedQuestionCard extends StatefulWidget {
  final Question question;
  final dynamic theme;
  const _SavedQuestionCard({required this.question, required this.theme});

  @override
  State<_SavedQuestionCard> createState() => _SavedQuestionCardState();
}

class _SavedQuestionCardState extends State<_SavedQuestionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = widget.theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClayContainer(
        borderRadius: 20,
        color: theme.cardColor,
        parentColor: theme.bgGradient.last,
        emboss: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Text
              Text(
                q.questionText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor, height: 1.3),
              ),
              const SizedBox(height: 16),
              
              // REVEAL BUTTON / ANSWER
              if (!_isExpanded)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(Icons.visibility_rounded, size: 18, color: theme.accentColor),
                    label: Text("View Answer", style: TextStyle(color: theme.accentColor)),
                    onPressed: () => setState(() => _isExpanded = true),
                  ),
                )
              else 
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3))
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Correct Answer: ${q.correctOption}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Text(_getOptionText(q.correctOption, q), style: TextStyle(color: theme.textColor)),
                      if (q.explanation != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text("Explanation:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.subTextColor)),
                        Text(q.explanation!, style: TextStyle(fontSize: 13, color: theme.textColor)),
                      ]
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getOptionText(String opt, Question q) {
    if (opt == 'A') return q.optionA;
    if (opt == 'B') return q.optionB;
    if (opt == 'C') return q.optionC;
    if (opt == 'D') return q.optionD;
    return "";
  }
}