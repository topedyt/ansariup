class Chapter {
  final String id; // Changed from int to String
  final int subjectId;
  final String title;
  final int chapterNumber;

  Chapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.chapterNumber,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as int,
      title: json['title'] as String,
      chapterNumber: json['chapter_number'] as int? ?? 0,
    );
  }
}