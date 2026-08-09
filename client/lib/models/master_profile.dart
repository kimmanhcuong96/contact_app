import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'master_profile.freezed.dart';
part 'master_profile.g.dart';

@freezed
class MasterProfile with _$MasterProfile {
  const MasterProfile._();

  const factory MasterProfile({
    required Map<String, String> fields,
    @JsonKey(name: 'avatar') String? avatarBase64,
  }) = _MasterProfile;

  factory MasterProfile.fromJson(Map<String, dynamic> json) =>
      _$MasterProfileFromJson(_normalizeMasterProfileJson(json));

  String encode() => jsonEncode(toJson());

  factory MasterProfile.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Master profile must be a JSON object');
    }
    return MasterProfile.fromJson(Map<String, dynamic>.from(decoded));
  }

  static const empty = MasterProfile(fields: {});
}

Map<String, dynamic> _normalizeMasterProfileJson(Map<String, dynamic> json) {
  final rawFields = json['fields'];
  if (rawFields != null && rawFields is! Map) {
    throw const FormatException('Master profile fields must be an object');
  }

  final source = rawFields is Map
      ? rawFields
      : <String, dynamic>{
          for (final key in profileFieldKeys)
            if (json.containsKey(key)) key: json[key],
        };
  final fields = <String, String>{};
  for (final entry in source.entries) {
    final value = entry.value;
    if (value != null) fields[entry.key.toString()] = value.toString();
  }

  final avatar = json['avatar'] ?? json['avatarBase64'];
  return {
    'fields': fields,
    if (avatar != null) 'avatar': avatar.toString(),
  };
}

const profileFieldKeys = <String>[
  'fullName',
  'nickname',
  'birthday',
  'gender',
  'company',
  'position',
  'phone',
  'email',
  'address',
  'website',
  'facebook',
  'instagram',
  'linkedIn',
  'telegram',
  'whatsApp',
  'weChat',
  'zalo',
  'github',
  'notes',
];
