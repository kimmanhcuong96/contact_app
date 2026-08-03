import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/models/master_profile.dart';
import 'package:nexbook/models/sharing_profile.dart';

void main() {
  test('master profile round-trips extensible fields', () {
    const profile = MasterProfile(fields: {'fullName': 'Ada', 'customField': 'future-safe'});
    expect(MasterProfile.decode(profile.encode()).fields, profile.fields);
  });

  test('sharing profile round-trips visibility policy', () {
    const profile = SharingProfile(id: 'id', name: 'Work', visibleFields: {'fullName', 'company'}, version: 3);
    final decoded = SharingProfile.decode(profile.encode());
    expect(decoded.visibleFields, profile.visibleFields);
    expect(decoded.version, 3);
  });
}

