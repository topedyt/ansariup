import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// 1. MODELS
// -----------------------------------------------------------------------------

class Subject {
  final int id;
  final String title;
  final String? description;
  final String? imageUrl;
  
  // 🟢 NEW FIELDS FOR UI CONFIGURATION
  final String iconKey;  
  final String colorHex; 

  Subject({
    required this.id, 
    required this.title, 
    this.description, 
    this.imageUrl,
    required this.iconKey,
    required this.colorHex,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      // Read new DB columns with safe defaults
      iconKey: json['icon_key'] as String? ?? 'book', 
      colorHex: json['color_hex'] as String? ?? 'FFFFFFFF', // Default White
    );
  }
}

class Chapter {
  final int id;
  final int subjectId;
  final String title;
  final bool isPaid;

  Chapter({required this.id, required this.subjectId, required this.title, required this.isPaid});

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as int,
      subjectId: json['subject_id'] as int,
      title: json['title'] as String,
      isPaid: json['is_paid'] as bool? ?? false,
    );
  }
}

class Question {
  final int id;
  final int chapterId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String? explanation;
  final String? pyqYear;
  final bool isPaid;

  Question({
    required this.id, required this.chapterId, required this.questionText,
    required this.optionA, required this.optionB, required this.optionC, required this.optionD,
    required this.correctOption, this.explanation, this.pyqYear, required this.isPaid,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      chapterId: json['chapter_id'] as int,
      questionText: json['question_text'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      correctOption: json['correct_option'] as String,
      explanation: json['explanation'] as String?,
      pyqYear: json['pyq_year'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
    );
  }
}

class DailyUpdate {
  final String factText;
  DailyUpdate({required this.factText});
}

// -----------------------------------------------------------------------------
// 2. PROVIDERS
// -----------------------------------------------------------------------------

final supabaseClientProvider = Provider((ref) => Supabase.instance.client);

// A. Fetch Subjects
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase.from('subjects').select().order('title');
  return (data as List).map((e) => Subject.fromJson(e)).toList();
});

// B. Fetch Chapters
final chaptersProvider = FutureProvider.family<List<Chapter>, int>((ref, subjectId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase.from('chapters').select().eq('subject_id', subjectId).order('id', ascending: true);
  return (data as List).map((e) => Chapter.fromJson(e)).toList();
});

// C. Fetch Raw Questions (Helper)
final _baseQuestionsProvider = FutureProvider.autoDispose.family<List<Question>, int>((ref, chapterId) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // 🎲 RANDOM MODE: If chapterId is 0, fetch random mix
  if (chapterId == 0) {
    // Calls the secure backend function that handles Pro/Free logic automatically
    final data = await supabase.rpc('get_random_questions');
    return (data as List).map((e) => Question.fromJson(e)).toList();
  }

  // STANDARD MODE: Fetch questions for specific chapter
  final data = await supabase.from('questions').select().eq('chapter_id', chapterId);
  return (data as List).map((e) => Question.fromJson(e)).toList();
});

// D. SMART RANDOMIZER (Unseen First)
final smartQuestionsProvider = FutureProvider.autoDispose.family<List<Question>, int>((ref, chapterId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  // 1. Get Questions (Handles standard or random via base provider)
  final allQuestions = await ref.watch(_baseQuestionsProvider(chapterId).future);
  if (allQuestions.isEmpty) return [];

  // 2. Guest User -> Just Shuffle
  if (userId == null) {
    var list = [...allQuestions];
    list.shuffle();
    return list;
  }

  // 3. Optimization: If random mode (large list), skip heavy logic
  if (chapterId == 0 || allQuestions.length > 100) {
     var list = [...allQuestions];
     list.shuffle(); // Just shuffle for random mode
     return list;
  }

  // 4. Get Attempted IDs (For standard chapters)
  final qIds = allQuestions.map((q) => q.id).toList();
  final attemptsResponse = await supabase
      .from('user_question_attempts')
      .select('question_id')
      .eq('user_id', userId)
      .filter('question_id', 'in', qIds);

  final attemptedIds = (attemptsResponse as List).map((e) => e['question_id'] as int).toSet();

  // 5. Split & Shuffle (Prioritize unseen)
  final unseen = allQuestions.where((q) => !attemptedIds.contains(q.id)).toList();
  final seen = allQuestions.where((q) => attemptedIds.contains(q.id)).toList();
  unseen.shuffle();
  seen.shuffle();

  return [...unseen, ...seen];
});

// E. Standard Questions (Test Mode - Ordered by ID)
final questionsProvider = FutureProvider.autoDispose.family<List<Question>, int>((ref, chapterId) async {
   final questions = await ref.watch(_baseQuestionsProvider(chapterId).future);
   return questions..sort((a, b) => a.id.compareTo(b.id)); 
});

// --- F. STATS PROVIDERS ---

// 1. REALTIME SCORE
final userScoreProvider = StreamProvider<double>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) => data.isNotEmpty ? (data.first['career_points'] as num).toDouble() : 0.0);
});

// 2. RANK
final userRankProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;

  ref.watch(userScoreProvider); // Refresh rank when score changes

  final data = await supabase
      .from('leaderboard')
      .select('global_rank')
      .eq('user_id', userId)
      .maybeSingle();
      
  return data != null ? (data['global_rank'] as int) : 0;
});

// G. Daily Fact
final dailyUpdateProvider = StreamProvider<DailyUpdate>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.from('daily_updates').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(1)
      .map((data) => DailyUpdate(factText: data.isEmpty ? "No wisdom today." : data.first['fact_text']));
});

// H. User Pro Status
final isUserProProvider = FutureProvider<bool>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return false;

  try {
    final data = await supabase
      .from('users')
      .select('is_pro')
      .eq('id', user.id)
      .maybeSingle();
      
    if (data == null) return false;
    return data['is_pro'] as bool? ?? false;
  } catch (e) {
    return false;
  }
});

// I. Check if Question is Bookmarked
final isBookmarkedProvider = FutureProvider.autoDispose.family<bool, int>((ref, questionId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final count = await supabase
      .from('user_bookmarks')
      .count(CountOption.exact)
      .eq('user_id', userId)
      .eq('question_id', questionId);
  
  return count > 0;
});

// J. Toggle Bookmark
final toggleBookmarkProvider = Provider((ref) {
  return (int questionId, bool currentStatus) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (currentStatus) {
      await supabase.from('user_bookmarks').delete().match({
        'user_id': userId,
        'question_id': questionId,
      });
    } else {
      await supabase.from('user_bookmarks').insert({
        'user_id': userId,
        'question_id': questionId,
      });
    }
  };
});

// K. Report Question
final reportQuestionProvider = Provider((ref) {
  return (int questionId, String issue) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('question_reports').insert({
      'user_id': userId,
      'question_id': questionId,
      'issue_text': issue,
    });
  };
});

// L. Fetch User's Saved Questions
final savedQuestionsProvider = FutureProvider.autoDispose<List<Question>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final data = await supabase
      .from('user_bookmarks')
      .select('questions(*)') // Inner Join
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => Question.fromJson(e['questions']))
      .toList();
});