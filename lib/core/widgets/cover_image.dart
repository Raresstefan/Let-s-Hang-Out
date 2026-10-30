import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a profile photo or legacy activity cover from a source that may be:
///   - a remote URL (`http://` / `https://`)  -> cached network image
///   - an inline data URL (`data:image/...;base64,...`) -> decoded in-memory
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.errorFallback,
  });

  final String source;
  final BoxFit fit;
  final Widget? errorFallback;

  bool get _isDataUrl => source.startsWith('data:');
  Widget get _fallback => errorFallback ?? const ColoredBox(color: Colors.black12);

  @override
  Widget build(BuildContext context) {
    if (_isDataUrl) {
      final bytes = _decodeDataUrl(source);
      if (bytes == null || bytes.isEmpty) {
        return _fallback;
      }
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      placeholder: (_, __) => Container(color: Colors.black12),
      errorWidget: (_, __, ___) => _fallback,
    );
  }

  static Uint8List? _decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  /// Image source for circular avatars and decorations across the app.
  static ImageProvider<Object> providerFor(String source) {
    if (!source.startsWith('data:')) return NetworkImage(source);
    final bytes = _decodeDataUrl(source);
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Invalid avatar image data');
    }
    return MemoryImage(bytes);
  }

  /// Builds a `data:` URL from raw image [bytes] for a given [extension].
  static String dataUrlFromBytes(Uint8List bytes, String extension) {
    final mime = (extension.toLowerCase() == 'png')
        ? 'image/png'
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
