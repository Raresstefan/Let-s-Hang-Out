import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'activity_cover_processor.dart';
import 'activity_cover_storage.dart';

class FirebaseActivityCoverStorage implements ActivityCoverStorage {
  FirebaseActivityCoverStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  @override
  Future<StoredActivityCover> upload({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      final prepared = await prepareActivityCover(bytes);
      if (prepared.lengthInBytes > maxStoredActivityCoverBytes) {
        throw StateError('Compressed cover exceeds 2 MB');
      }
      final path = 'activity-covers/$userId/${_uuid.v4()}.jpg';
      final reference = _storage.ref(path);
      await reference.putData(
        prepared,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        ),
      );
      return StoredActivityCover(
        url: await reference.getDownloadURL(),
        path: path,
      );
    } catch (error) {
      throw ActivityCoverUploadException(error);
    }
  }

  @override
  Future<void> delete(String path) => _storage.ref(path).delete();
}
