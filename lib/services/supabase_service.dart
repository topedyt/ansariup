import 'package:supabase_flutter/supabase_flutter.dart';
// IMPORT the models from your library providers file
import '../features/library/library_providers.dart'; 

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fix: Change ChapterModel to Chapter
  Future<List<Chapter>> getChapters(int subjectId) async {
    final response = await _client
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('chapter_number', ascending: true);

    final data = response as List<dynamic>;
    // Fix: Use Chapter.fromJson
    return data.map((json) => Chapter.fromJson(json)).toList();
  }

  // Fix: Change QuestionModel to Question
  // Fix: Change chapterId type to String (UUID)
  Future<List<Question>> getQuestions(String chapterId) async {
    final response = await _client
        .from('questions')
        .select()
        .eq('chapter_id', chapterId);

    final data = response as List<dynamic>;
    // Fix: Use Question.fromJson
    return data.map((json) => Question.fromJson(json)).toList();
  }
}