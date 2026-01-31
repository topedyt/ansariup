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
    required this.id,
    required this.chapterId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
    this.pyqYear,
    required this.isPaid,
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