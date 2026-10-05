import 'dart:typed_data';

import '../../core/widgets/cover_image.dart';
import 'activity_cover_processor.dart';
import 'activity_cover_storage.dart';

class InlineActivityCoverStorage implements ActivityCoverStorage {
  @override
  Future<StoredActivityCover> upload({
    required String userId,
    required Uint8List bytes,
  }) async {
    final prepared = await prepareActivityCover(bytes);
    return StoredActivityCover(
      url: CoverImage.dataUrlFromBytes(prepared, 'jpg'),
      path: '',
    );
  }

  @override
  Future<void> delete(String path) async {}
}
