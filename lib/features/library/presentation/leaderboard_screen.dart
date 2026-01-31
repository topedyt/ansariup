import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/clay_kit.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/mesh_background.dart';
import '../library_providers.dart';

// Provider to fetch Top 50 Users
final leaderboardListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('leaderboard')
      .select()
      .order('global_rank', ascending: true)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final leaderboardAsync = ref.watch(leaderboardListProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

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
                    Text("Global Leaders", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.textColor)),
                  ],
                ),
              ),

              // LIST
              Expanded(
                child: leaderboardAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: theme.accentColor)),
                  error: (e,s) => Center(child: Text("Error: $e")),
                  data: (users) {
                    if (users.isEmpty) return const Center(child: Text("No data yet."));
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final rank = user['global_rank'] as int;
                        final name = user['full_name'] ?? 'Unknown';
                        final score = (user['career_points'] as num).toInt();
                        final isMe = user['user_id'] == myId;

                        // Trophies for Top 3
                        Color? rankColor;
                        IconData? rankIcon;
                        
                        if (rank == 1) { rankColor = const Color(0xFFFFD700); rankIcon = Icons.emoji_events; } // Gold
                        else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); rankIcon = Icons.emoji_events; } // Silver
                        else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = Icons.emoji_events; } // Bronze

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClayContainer(
                            width: double.infinity,
                            borderRadius: 20,
                            color: isMe ? theme.accentColor.withOpacity(0.1) : theme.cardColor, // Highlight me
                            parentColor: theme.bgGradient.last,
                            emboss: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  // Rank Badge
                                  Container(
                                    width: 40, height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: rankColor?.withOpacity(0.2) ?? theme.subTextColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: rankIcon != null 
                                      ? Icon(rankIcon, color: rankColor, size: 20)
                                      : Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, color: theme.subTextColor)),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textColor)),
                                        if (isMe) 
                                          Text("(You)", style: TextStyle(fontSize: 12, color: theme.accentColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),

                                  // Score
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("$score XP", style: TextStyle(fontWeight: FontWeight.w900, color: theme.textColor)),
                                      Text("Points", style: TextStyle(fontSize: 10, color: theme.subTextColor)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
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