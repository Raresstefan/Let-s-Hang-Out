import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders an activity cover image from a source string that may be either:
///   - a remote URL (`http://` / `https://`)  -> cached network image
///   - an inline data URL (`data:image/...;base64,...`) -> decoded in-memory
///
/// The data-URL path lets a user's drag-dropped/picked image render with no
/// backend. Once Firebase Storage is wired, picked images upload there and the
/// source becomes a normal https URL — this widget handles both transparently.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.source, this.fit = BoxFit.cover});

  final String source;
  final BoxFit fit;

  bool get _isDataUrl => source.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    if (_isDataUrl) {
      final bytes = _decodeDataUrl(source);
      if (bytes == null || bytes.isEmpty) {
        return const ColoredBox(color: Colors.black12);
      }
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      placeholder: (_, __) => Container(color: Colors.black12),
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black12),
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

  /// Builds a `data:` URL from raw image [bytes] for a given [extension]
  /// (e.g. `png`, `jpg`). Used by the cover picker so the value flows through
  /// the existing `coverImageUrl` String field unchanged.
  static String dataUrlFromBytes(Uint8List bytes, String extension) {
    final mime = (extension.toLowerCase() == 'png')
        ? 'image/png'
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
