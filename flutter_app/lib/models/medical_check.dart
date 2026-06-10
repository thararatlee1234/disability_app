class CheckPhoto {
  final int id;
  final String? image;

  CheckPhoto({
    required this.id,
    this.image,
  });

  factory CheckPhoto.fromJson(Map<String, dynamic> json) {
    return CheckPhoto(
      id: json['id'] ?? 0,
      image: json['image'],
    );
  }
}

class MedicalCheck {
  final int id;
  final int person;
  final String checkDate;
  final String detail;
  final List<CheckPhoto> photos;

  MedicalCheck({
    required this.id,
    required this.person,
    required this.checkDate,
    required this.detail,
    required this.photos,
  });

  factory MedicalCheck.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List? ?? [];
    return MedicalCheck(
      id: json['id'] ?? 0,
      person: json['person'] ?? 0,
      checkDate: json['check_date'] ?? '',
      detail: json['detail'] ?? '',
      photos: rawPhotos
          .map((photo) => CheckPhoto.fromJson(photo as Map<String, dynamic>))
          .toList(),
    );
  }
}
