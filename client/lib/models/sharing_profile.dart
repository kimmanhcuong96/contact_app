import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sharing_profile.freezed.dart';
part 'sharing_profile.g.dart';

@freezed
class SharingProfile with _$SharingProfile {
  const SharingProfile._();

  const factory SharingProfile({
    required String id,
    required String name,
    required Set<String> visibleFields,
    @Default(1) int version,
  }) = _SharingProfile;

  factory SharingProfile.fromJson(Map<String, dynamic> json) =>
      _$SharingProfileFromJson(json);

  String encode() => jsonEncode(toJson());

  factory SharingProfile.decode(String value) =>
      SharingProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
