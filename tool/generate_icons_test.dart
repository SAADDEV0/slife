// Generates SLife's launcher icons (Android legacy mipmaps + iOS AppIcon set).
//
//   flutter test tool/generate_icons_test.dart
//
// The Android adaptive icon (API 26+) uses the vector drawables in
// android/app/src/main/res/drawable/ic_launcher_*.xml, which share the same
// "S" path as [Brand.sPath].
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slife/theme/brand.dart';

Future<Uint8List> _render(
  int size, {
  required bool rounded,
  required bool opaque,
}) async {
  final recorder = ui.PictureRecorder();
  Brand.paintIcon(Canvas(recorder), size.toDouble(), rounded: rounded);
  final image = await recorder.endRecording().toImage(size, size);
  if (!opaque) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _encodeRgbPng(rgba!.buffer.asUint8List(), size, size);
}

/// Minimal PNG encoder without an alpha channel (the App Store rejects
/// icons that have one).
Uint8List _encodeRgbPng(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32([...typeBytes, ...data])));
  }

  chunk('IHDR', [..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void main() {
  test('generate launcher icons', () async {
    final root = Directory.current.path;
    Future<void> write(String path, Uint8List bytes) async {
      final file = File('$root/$path');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }

    // Android (API 24–25 legacy icons; 26+ uses the adaptive vector icon).
    const android = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final MapEntry(key: density, value: size) in android.entries) {
      await write(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        await _render(size, rounded: true, opaque: false),
      );
    }

    // iOS: every image listed in the AppIcon set, full-bleed and opaque.
    const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = File('$root/$iosDir/Contents.json').readAsStringSync();
    final pattern = RegExp(
      r'"size"\s*:\s*"([\d.]+)x[\d.]+".*?"filename"\s*:\s*"([^"]+)".*?"scale"\s*:\s*"(\d)x"',
      dotAll: true,
    );
    for (final m in pattern.allMatches(contents)) {
      final px = (double.parse(m.group(1)!) * int.parse(m.group(3)!)).round();
      await write(
        '$iosDir/${m.group(2)}',
        await _render(px, rounded: false, opaque: true),
      );
    }

    // Preview for the README.
    await write(
      'docs/icon.png',
      await _render(512, rounded: true, opaque: false),
    );
  });
}
