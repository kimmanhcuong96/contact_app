import 'dart:convert';

class SharingProfile {
  const SharingProfile({required this.id, required this.name, required this.visibleFields, required this.version});
  final String id;
  final String name;
  final Set<String> visibleFields;
  final int version;

  SharingProfile copyWith({String? id, String? name, Set<String>? visibleFields, int? version}) => SharingProfile(
        id: id ?? this.id, name: name ?? this.name, visibleFields: visibleFields ?? this.visibleFields, version: version ?? this.version);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'visibleFields': visibleFields.toList(), 'version': version};
  factory SharingProfile.fromJson(Map<String, dynamic> json) => SharingProfile(
        id: json['id'] as String, name: json['name'] as String,
        visibleFields: Set<String>.from(json['visibleFields'] as List), version: json['version'] as int? ?? 1);
  String encode() => jsonEncode(toJson());
  factory SharingProfile.decode(String value) => SharingProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

