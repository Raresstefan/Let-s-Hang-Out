import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import 'cover_image.dart';

/// Shared image picking/validation logic used by both the activity cover drop
/// zone and the profile avatar drop zone. Keeps the desktop_drop + file_picker
/// + png/jpg validation + data-URL encoding in one place.
const List<String> kImageExtensions = ['png', 'jpg', 'jpeg'];

bool isAllowedImageName(String name) {
  final lower = name.toLowerCase();
  return kImageExtensions.any((e) => lower.endsWith('.$e'));
}

/// Outcome of an image pick. Exactly one of [dataUrl] or [error] is non-null.
class PickedImage {
  const PickedImage._({this.dataUrl, this.fileName, this.error});

  /// `data:image/...;base64,...` ready to render via [CoverImage] / store in a
  /// `*ImageUrl` field.
  final String? dataUrl;
  final String? fileName;

  /// A user-facing error message (wrong type / unreadable). Null on success.
  final String? error;

  bool get ok => dataUrl != null;

  static const _wrongType = 'Please choose a .png or .jpg image';
  static const _unreadable =
      "Couldn't read that image. Try clicking to browse instead.";

  static PickedImage _success(Uint8List bytes, String name) {
    final ext = name.contains('.') ? name.split('.').last : 'png';
    return PickedImage._(
      dataUrl: CoverImage.dataUrlFromBytes(bytes, ext),
      fileName: name,
    );
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
    if (bytes.isEmpty) {
      return const PickedImage._(error: _unreadable);
    }
    return _success(bytes, file.name);
  }

  /// Open the file browser and process the selection. Returns null if the user
  /// cancelled.
  static Future<PickedImage?> browse() async {
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
    return _success(bytes, file.name);
  }
}
