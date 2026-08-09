import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zxing2/qrcode.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';

enum _QrMode { mine, scan }

String? decodeQrImage(Uint8List bytes) {
  try {
    final image = image_lib.decodeImage(bytes);
    if (image == null) return null;
    final source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: image_lib.ChannelOrder.rgba)
          .buffer
          .asInt32List(),
    );
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
  } catch (_) {
    return null;
  }
}

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key, required this.onConnectionCreated});

  final VoidCallback onConnectionCreated;

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  final _scanner = MobileScannerController(autoStart: false);
  final _picker = ImagePicker();
  _QrMode _mode = _QrMode.mine;
  bool _handlingScan = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: _mode == _QrMode.scan
            ? IconButton(
                tooltip: l10n.t('myQr'),
                onPressed: () => _changeMode(const {_QrMode.mine}),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          _mode == _QrMode.mine ? l10n.t('myQr') : l10n.t('scanQr'),
        ),
      ),
      body: _mode == _QrMode.mine ? _buildMyQr() : _buildScanner(),
    );
  }

  void _changeMode(Set<_QrMode> selection) {
    final next = selection.first;
    if (next == _mode) return;
    if (next == _QrMode.mine) _scanner.stop();
    setState(() => _mode = next);
    if (next == _QrMode.scan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == _QrMode.scan) _scanner.start();
      });
    }
  }

  Widget _buildMyQr() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ref.watch(accountProvider).when(
                  data: (me) {
                    final payload = 'nexbook:user:${me['id']}';
                    final username = me['username'] as String;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: QrImageView(data: payload, size: 240),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('@$username',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: () => _changeMode(const {_QrMode.scan}),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(context.l10n.t('scanQr')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _saveQr(payload, username),
                                icon: const Icon(Icons.download_outlined),
                                label: Text(context.l10n.t('saveQr')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareQr(payload, username),
                                icon: const Icon(Icons.share_outlined),
                                label: Text(context.l10n.t('shareQr')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => Text(context.l10n.t('cannotLoadQr')),
                ),
          ),
        ),
      );

  Widget _buildScanner() => Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _handleCapture,
                ),
                IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(constraints.maxWidth * 0.68, 280.0);
                      return Center(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _ScannerControl(
                        tooltip: context.l10n.t('toggleFlash'),
                        icon: Icons.flashlight_on_outlined,
                        onPressed: _scanner.toggleTorch,
                      ),
                      const SizedBox(width: 8),
                      _ScannerControl(
                        tooltip: context.l10n.t('switchCamera'),
                        icon: Icons.cameraswitch_outlined,
                        onPressed: _scanner.switchCamera,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _pickQrImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.l10n.t('uploadQrImage')),
                ),
              ),
            ),
          ),
        ],
      );

  Future<Uint8List> _qrPng(String payload) async {
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size.square(1024);
    canvas.drawColor(Colors.white, BlendMode.src);
    painter.paint(canvas, size);
    final image = await recorder.endRecording().toImage(1024, 1024);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not render QR image');
    return data.buffer.asUint8List();
  }

  Future<void> _saveQr(String payload, String username) async {
    try {
      await FileSaver.instance.saveFile(
        name: 'nexbook-$username-qr',
        bytes: await _qrPng(payload),
        ext: 'png',
        mimeType: MimeType.png,
      );
      if (mounted) _showMessage(context.l10n.t('qrSaved'));
    } catch (error) {
      if (mounted) _showMessage(localizedError(context.l10n, error));
    }
  }

  Future<void> _shareQr(String payload, String username) async {
    try {
      final subject = context.l10n.t('shareQrSubject');
      final bytes = await _qrPng(payload);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'nexbook-qr.png',
          ),
        ],
        subject: subject,
        text: '@$username',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      if (mounted) _showMessage(localizedError(context.l10n, error));
    }
  }

  Future<void> _pickQrImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final raw = decodeQrImage(await picked.readAsBytes());
    if (raw == null) {
      if (mounted) _showMessage(context.l10n.t('qrNotFound'));
      return;
    }
    await _handleRawValue(raw);
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null) await _handleRawValue(raw);
  }

  Future<void> _handleRawValue(String raw) async {
    if (_handlingScan || !raw.startsWith('nexbook:user:')) return;
    final peerId = raw.substring('nexbook:user:'.length);
    if (peerId.isEmpty) return;
    _handlingScan = true;
    await _scanner.stop();
    try {
      final sharing = await _chooseSharing();
      if (sharing == null) return;
      final refreshed =
          await ref.read(connectionRepositoryProvider).request(peerId, sharing);
      if (mounted) {
        _showMessage(context.l10n
            .t(refreshed ? 'connectionRefreshed' : 'connectionQueued'));
        setState(() => _mode = _QrMode.mine);
        widget.onConnectionCreated();
      }
    } catch (error) {
      if (mounted) _showMessage(localizedError(context.l10n, error));
    } finally {
      _handlingScan = false;
      if (mounted && _mode == _QrMode.scan) await _scanner.start();
    }
  }

  Future<SharingProfileRow?> _chooseSharing() async {
    final database = ref.read(databaseProvider);
    final rows = await database.select(database.sharingProfiles).get();
    if (!mounted || rows.isEmpty) return null;
    return showDialog<SharingProfileRow>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.t('shareWhichProfile')),
        children: rows
            .map((row) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, row),
                  child: Text(context.l10n.defaultProfileName(
                      jsonDecode(row.json)['name'] as String)),
                ))
            .toList(),
      ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _ScannerControl extends StatelessWidget {
  const _ScannerControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      );
}
