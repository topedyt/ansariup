import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../library_providers.dart';
import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';

class ChapterListScreen extends ConsumerWidget {
  final int subjectId;
  const ChapterListScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));
    final theme = ref.watch(appThemeProvider);

    return Scaffold(
      body: MeshBackground(
        theme: theme,
        child: SafeArea(
          child: Column(
            children: [
              // 1. HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: ClayContainer(
                        height: 50, width: 50, borderRadius: 25,
                        color: theme.cardColor,
                        parentColor: theme.bgGradient.first,
                        emboss: false,
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Select Mission", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.subTextColor)),
                        Text("Chapters", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: theme.textColor, height: 1.0)),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. CHAPTER LIST
              Expanded(
                child: chaptersAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: theme.accentColor)),
                  error: (e, _) => Center(child: Text("Error: $e")),
                  data: (chapters) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      // Alternate colors for the Level Number box
                      final colors = [Colors.blue, Colors.purple, Colors.orange, Colors.teal, Colors.red];
                      final color = colors[index % colors.length];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: GestureDetector(
                          onTap: () => _showModeSelectionSheet(context, chapter.id, chapter.title, theme),
                          child: ClayContainer(
                            width: double.infinity,
                            borderRadius: 24,
                            color: theme.cardColor,
                            parentColor: theme.bgGradient.first,
                            emboss: false,
                            spread: 3,
                            child: Stack(
                              children: [
                                // Background Watermark
                                Positioned(
                                  right: -10, bottom: -15,
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      fontSize: 80, 
                                      fontWeight: FontWeight.w900, 
                                      color: color.withOpacity(0.05)
                                    ),
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      // Level Number Box
                                      Container(
                                        height: 50, width: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: color.withOpacity(0.3), width: 2)
                                        ),
                                        child: Text(
                                          "${index + 1}", 
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Title
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chapter.title, 
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.textColor, height: 1.2),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.bolt_rounded, size: 14, color: theme.subTextColor),
                                                const SizedBox(width: 4),
                                                Text("Ready", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.subTextColor)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 12),

                                      // --- 🟢 NEW START BUTTON ---
                                      const GlassmorphicStartButton(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODE SHEET (Unchanged Logic) ---
  void _showModeSelectionSheet(BuildContext context, int chapterId, String title, dynamic theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text("CHOOSE MODE", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.subTextColor, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.textColor), maxLines: 2),
            const SizedBox(height: 32),
            
            _GamifiedModeCard(theme: theme, title: "Practice", subtitle: "Unlimited time • Explanations", icon: Icons.school_rounded, color: Colors.blueAccent, onTap: () { context.pop(); context.push('/quiz/$chapterId?mode=practice'); }),
            const SizedBox(height: 16),
            _GamifiedModeCard(theme: theme, title: "Ranked Test", subtitle: "Timed • High XP Rewards", icon: Icons.emoji_events_rounded, color: Colors.orange, onTap: () { context.pop(); _showQuestionCountDialog(context, chapterId, theme); }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showQuestionCountDialog(BuildContext context, int chapterId, dynamic theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Configure Test", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("How many questions?", style: TextStyle(color: theme.subTextColor)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: [10, 20, 30, 50].map((count) {
                return GestureDetector(
                  onTap: () { context.pop(); context.push('/quiz/$chapterId?mode=test&count=$count'); },
                  child: ClayContainer(height: 50, width: 80, borderRadius: 16, color: theme.cardColor, emboss: false, child: Center(child: Text("$count", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 18)))),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 🟢 NEW: GLASSMORPHIC START BUTTON WIDGET ---
class GlassmorphicStartButton extends StatelessWidget {
  const GlassmorphicStartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                "START",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamifiedModeCard extends StatelessWidget {
  final dynamic theme; final String title, subtitle; final IconData icon; final Color color; final VoidCallback onTap;
  const _GamifiedModeCard({required this.theme, required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        height: 80, borderRadius: 24, color: theme.cardColor, parentColor: theme.bgGradient.last, emboss: false, spread: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: theme.subTextColor, fontWeight: FontWeight.w600)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: theme.subTextColor.withOpacity(0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
