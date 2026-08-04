import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';

class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('myQr'))),
      body: Center(
          child: ref.watch(accountProvider).when(
                data: (me) {
                  final payload = 'nexbook:user:${me['id']}';
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(28),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            QrImageView(data: payload, size: 240),
                            const SizedBox(height: 16),
                            Text('@${me['username']}'),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: () => Share.share(payload,
                                    subject: context.l10n.t('shareQrSubject')),
                                icon: const Icon(Icons.share),
                                label: Text(context.l10n.t('shareQrLink')))
                          ])));
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => Text(context.l10n.t('cannotLoadQr')),
              )));
}
