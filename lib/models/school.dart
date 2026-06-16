class School {
  final String id;
  final String name;
  final String city;
  final String state;
  final String district;

  const School({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    this.district = '',
  });

  String get displayLabel {
    if (city.isEmpty) return '$name, $state';
    return '$name — $city, $state';
  }

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'state': state,
        'district': district,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is School && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SchoolSearchException implements Exception {
  final String message;

  const SchoolSearchException(this.message);

  @override
  String toString() => message;
}
