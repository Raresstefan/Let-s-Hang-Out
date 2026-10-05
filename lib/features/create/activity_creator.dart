import 'package:flutter/foundation.dart';

import '../../data/repositories/activity_repository.dart';
import '../../data/storage/activity_cover_storage.dart';
import '../../domain/models/activity.dart';

class ActivityCreator {
  ActivityCreator(this._repository, this._coverStorage);

  final ActivityRepository _repository;
  final ActivityCoverStorage _coverStorage;

  /// Uploads the optional cover, then persists [draft]. Returns the stored
  /// activity (with its generated id).
  Future<Activity> create(Activity draft, {Uint8List? coverBytes}) async {
    StoredActivityCover? uploaded;
    try {
      if (coverBytes != null) {
        uploaded = await _coverStorage.upload(
          userId: draft.hostId,
          bytes: coverBytes,
        );
      }
      return await _repository.createActivity(
        uploaded == null ? draft : draft.copyWith(coverImageUrl: uploaded.url),
      );
    } catch (error, stackTrace) {
      if (uploaded != null && uploaded.path.isNotEmpty) {
        try {
          await _coverStorage.delete(uploaded.path);
        } catch (cleanupError, cleanupStackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: cleanupError,
              stack: cleanupStackTrace,
              context: ErrorDescription(
                'while cleaning up an unreferenced activity cover',
              ),
            ),
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
