import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';

final myAccountProvider = FutureProvider<Map<String, dynamic>>((ref) async =>
    (await ref.watch(apiClientProvider).dio.get<Map<String, dynamic>>('/me'))
        .data!);

class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('My QR')),
      body: Center(
          child: ref.watch(myAccountProvider).when(
                data: (me) {
                  final payload = 'nexbook:user:${me['id']}';
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(28),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            QrImageView(data: payload, size: 240),
                            const SizedBox(height: 16),
                            Text(me['email'] as String),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: () => Share.share(payload,
                                    subject: 'Connect with me on NexBook'),
                                icon: const Icon(Icons.share),
                                label: const Text('Share QR link'))
                          ])));
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Cannot load QR: $error'),
              )));
}
