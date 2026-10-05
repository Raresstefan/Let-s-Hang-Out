import 'dart:typed_data';

class StoredActivityCover {
  const StoredActivityCover({required this.url, required this.path});

  final String url;
  final String path;
}

class ActivityCoverUploadException implements Exception {
  const ActivityCoverUploadException(this.cause);

  final Object cause;

  @override
  String toString() => 'Activity cover upload failed: $cause';
}

abstract class ActivityCoverStorage {
  Future<StoredActivityCover> upload({
    required String userId,
    required Uint8List bytes,
  });

  Future<void> delete(String path);
}
