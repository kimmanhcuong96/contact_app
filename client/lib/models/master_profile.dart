import 'dart:convert';

class MasterProfile {
  const MasterProfile({required this.fields, this.avatarBase64});

  final Map<String, String> fields;
  final String? avatarBase64;

  MasterProfile copyWith({Map<String, String>? fields, String? avatarBase64}) =>
      MasterProfile(fields: fields ?? this.fields, avatarBase64: avatarBase64 ?? this.avatarBase64);

  Map<String, dynamic> toJson() => {'fields': fields, if (avatarBase64 != null) 'avatar': avatarBase64};
  factory MasterProfile.fromJson(Map<String, dynamic> json) => MasterProfile(
        fields: Map<String, String>.from(json['fields'] as Map? ?? const {}),
        avatarBase64: json['avatar'] as String?,
      );
  String encode() => jsonEncode(toJson());
  factory MasterProfile.decode(String value) => MasterProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);

  static const empty = MasterProfile(fields: {});
}

const profileFieldLabels = <String, String>{
  'fullName': 'Full name', 'nickname': 'Nickname', 'birthday': 'Birthday',
  'gender': 'Gender', 'company': 'Company', 'position': 'Position',
  'phone': 'Phone', 'email': 'Email', 'address': 'Address', 'website': 'Website',
  'facebook': 'Facebook', 'instagram': 'Instagram', 'linkedIn': 'LinkedIn',
  'telegram': 'Telegram', 'whatsApp': 'WhatsApp', 'weChat': 'WeChat',
  'zalo': 'Zalo', 'github': 'GitHub', 'notes': 'Notes',
};

