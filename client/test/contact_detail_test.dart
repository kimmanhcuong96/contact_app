import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/database/app_database.dart';
import 'package:nexbook/core/localization/app_localizations.dart';
import 'package:nexbook/features/connections/contact_detail_screen.dart';

void main() {
  test('maps shared contact fields to actionable URIs', () {
    expect(contactActionUri('phone', '+84 901 234 567').toString(),
        'tel:+84%20901%20234%20567');
    expect(contactActionUri('email', 'person@example.com').toString(),
        'mailto:person@example.com');
    expect(contactActionUri('facebook', '@nexbook').toString(),
        'https://facebook.com/nexbook');
    expect(contactActionUri('website', 'example.com').toString(),
        'https://example.com');
    expect(contactActionUri('notes', 'Private note'), isNull);
  });

  testWidgets('shows the decrypted fields shared by a contact', (tester) async {
    final contact = ConnectedProfileRow(
      connectionId: 'connection-id',
      peerUserId: 'peer-id',
      peerUsername: 'peer.user',
      status: 'connected',
      direction: 'incoming',
      profileJson: '{"fields":{"fullName":"Peer Name","phone":"0901234567"}}',
      version: 1,
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ContactDetailScreen(contact: contact),
    ));

    expect(find.text('Peer Name'), findsNWidgets(2));
    expect(find.text('@peer.user'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
  });
}
