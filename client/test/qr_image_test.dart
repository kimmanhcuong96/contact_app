import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/features/qr/qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  test('decodes a NexBook QR image selected from storage', () async {
    const payload = 'nexbook:user:12345678';
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size.square(512);
    canvas.drawColor(Colors.white, BlendMode.src);
    painter.paint(canvas, size);
    final image = await recorder.endRecording().toImage(512, 512);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    expect(decodeQrImage(data!.buffer.asUint8List()), payload);
  });
}
