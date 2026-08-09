import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/models/master_profile.dart';
import 'package:nexbook/models/sharing_profile.dart';

void main() {
  test('master profile round-trips extensible fields', () {
    const profile = MasterProfile(
        fields: {'fullName': 'Ada', 'customField': 'future-safe'});
    expect(MasterProfile.decode(profile.encode()).fields, profile.fields);
    expect(MasterProfile.decode(profile.encode()), profile);
    expect(
      () => profile.fields['fullName'] = 'Grace',
      throwsUnsupportedError,
    );
  });

  test('master profile reads legacy and loosely typed local data', () {
    final profile = MasterProfile.decode('''
      {
        "fields": {"fullName": "An", "phone": 123, "notes": null},
        "avatarBase64": "legacy-avatar"
      }
    ''');

    expect(profile.fields, {'fullName': 'An', 'phone': '123'});
    expect(profile.avatarBase64, 'legacy-avatar');
    expect(MasterProfile.decode('{}'), MasterProfile.empty);
  });

  test('master profile rejects structurally corrupted local data', () {
    expect(
      () => MasterProfile.decode('{"fields": []}'),
      throwsFormatException,
    );
  });

  test('sharing profile round-trips visibility policy', () {
    const profile = SharingProfile(
        id: 'id',
        name: 'Work',
        visibleFields: {'fullName', 'company'},
        version: 3);
    final decoded = SharingProfile.decode(profile.encode());
    expect(decoded.visibleFields, profile.visibleFields);
    expect(decoded.version, 3);
  });
}
