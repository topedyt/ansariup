class SubjectModel {
  final int id;
  final String title;
  final String? iconUrl; // URL to an icon image

  SubjectModel({
    required this.id,
    required this.title,
    this.iconUrl,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? 'Unknown Subject',
      iconUrl: map['icon_url'],
    );
  }
}