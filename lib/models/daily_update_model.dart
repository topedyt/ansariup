class DailyUpdateModel {
  final int id;
  final String factText; // The "Did you know?" text
  final String? imageUrl; // Optional image

  DailyUpdateModel({
    required this.id,
    required this.factText,
    this.imageUrl,
  });

  factory DailyUpdateModel.fromMap(Map<String, dynamic> map) {
    return DailyUpdateModel(
      id: map['id'] ?? 0,
      factText: map['fact_text'] ?? 'Welcome to UP Pariksha!',
      imageUrl: map['news_image_url'],
    );
  }
}