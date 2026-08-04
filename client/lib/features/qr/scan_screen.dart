import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/localization/app_localizations.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool handled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('scanQr'))),
      body: MobileScanner(onDetect: (capture) {
        if (handled) return;
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (value?.startsWith('nexbook:user:') == true) {
          handled = true;
          Navigator.pop(context, value!.substring('nexbook:user:'.length));
        }
      }));
}
