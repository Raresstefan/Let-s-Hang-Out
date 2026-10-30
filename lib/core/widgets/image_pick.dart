import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;

import 'cover_image.dart';

/// Shared image picking/validation logic used by both the activity cover drop
/// zone and the profile avatar drop zone. Keeps the desktop_drop + file_picker
/// + png/jpg validation + data-URL encoding in one place.
const List<String> kImageExtensions = ['png', 'jpg', 'jpeg'];

bool isAllowedImageName(String name) {
  final lower = name.toLowerCase();
  return kImageExtensions.any((e) => lower.endsWith('.$e'));
}

// Avatars live in the profile document. Bound the encoded size well below
// Firestore's 1 MiB document limit, including base64 overhead.
Future<String> avatarDataUrl(Uint8List bytes) => compute(_encodeAvatar, bytes);

String _encodeAvatar(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw StateError('The selected image could not be read');
  final avatar = image.copyResizeCropSquare(
    image.bakeOrientation(decoded),
    size: 512,
  );
  final encoded = image.encodeJpg(avatar, quality: 80);
  if (encoded.length > 256 * 1024) {
    throw StateError('The selected image is too large for a profile photo');
  }
  return CoverImage.dataUrlFromBytes(encoded, 'jpg');
}

/// Outcome of an image pick. Exactly one of [dataUrl] or [error] is non-null.
class PickedImage {
  const PickedImage._({
    this.bytes,
    this.dataUrl,
    this.fileName,
    this.contentType,
    this.error,
  });

  final Uint8List? bytes;
  final String? dataUrl;
  final String? fileName;
  final String? contentType;

  /// A user-facing error message (wrong type / unreadable). Null on success.
  final String? error;

  bool get ok => bytes != null && dataUrl != null;

  static const _wrongType = 'Please choose a .png or .jpg image';
  static const _unreadable =
      "Couldn't read that image. Try clicking to browse instead.";
  static const _tooLarge = 'Please choose an image smaller than 10 MB.';
  static const _maxInputBytes = 10 * 1024 * 1024;

  static PickedImage _success(Uint8List bytes, String name) {
    final ext = name.contains('.') ? name.split('.').last : 'png';
    final contentType = ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
    return PickedImage._(
      bytes: bytes,
      dataUrl: CoverImage.dataUrlFromBytes(bytes, ext),
      fileName: name,
      contentType: contentType,
    );
  }

  static PickedImage _fromBytes(Uint8List bytes, String name) {
    if (bytes.isEmpty) return const PickedImage._(error: _unreadable);
    if (bytes.lengthInBytes > _maxInputBytes) {
      return const PickedImage._(error: _tooLarge);
    }
    return _success(bytes, name);
  }

  /// Process a desktop_drop drop event into a [PickedImage]. Returns null if
  /// nothing usable was dropped.
  static Future<PickedImage?> fromDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return null;
    final file = details.files.first;
    if (!isAllowedImageName(file.name)) {
      return const PickedImage._(error: _wrongType);
    }
    final bytes = await file.readAsBytes();
    return _fromBytes(bytes, file.name);
  }

  /// Open Photos on iOS and the filtered file browser elsewhere.
  /// Returns null if the user cancelled.
  static Future<PickedImage?> browse() async {
    final usePhotos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (usePhotos) {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (photo == null) return null;
      if (!isAllowedImageName(photo.name)) {
        return const PickedImage._(error: _wrongType);
      }
      return _fromBytes(await photo.readAsBytes(), photo.name);
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kImageExtensions,
      withData: true, // we need bytes for the in-memory preview
    );
    final file = result?.files.firstOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes == null || !isAllowedImageName(file.name)) {
      return const PickedImage._(error: _wrongType);
    }
    return _fromBytes(bytes, file.name);
  }
}
