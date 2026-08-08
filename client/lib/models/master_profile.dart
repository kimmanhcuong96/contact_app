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
      _$MasterProfileFromJson(json);

  String encode() => jsonEncode(toJson());

  factory MasterProfile.decode(String value) =>
      MasterProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);

  static const empty = MasterProfile(fields: {});
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
