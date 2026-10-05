import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

const maxStoredActivityCoverBytes = 2 * 1024 * 1024;

Future<Uint8List> prepareActivityCover(Uint8List bytes) =>
    compute(_prepareCover, bytes);

Uint8List _prepareCover(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw StateError('The selected image could not be read');

  var prepared = image.bakeOrientation(decoded);
  const maxWidth = 1600;
  const maxHeight = 1200;
  final scale = [
    maxWidth / prepared.width,
    maxHeight / prepared.height,
    1.0,
  ].reduce((a, b) => a < b ? a : b);
  if (scale < 1) {
    prepared = image.copyResize(
      prepared,
      width: (prepared.width * scale).round(),
      height: (prepared.height * scale).round(),
    );
  }

  var encoded = image.encodeJpg(prepared, quality: 82);
  if (encoded.lengthInBytes > maxStoredActivityCoverBytes) {
    encoded = image.encodeJpg(prepared, quality: 68);
  }
  return encoded;
}
