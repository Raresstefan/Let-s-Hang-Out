import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/data/repositories/activity_repository.dart';
import 'package:hangout/data/storage/activity_cover_storage.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/features/create/activity_creator.dart';

void main() {
  test('stores the uploaded cover URL on the created activity', () async {
    final repository = _ActivityRepository();
    final storage = _CoverStorage();
    final creator = ActivityCreator(repository, storage);

    await creator.create(_draft(), coverBytes: Uint8List.fromList([1, 2, 3]));

    expect(storage.uploadCount, 1);
    expect(repository.created?.coverImageUrl, 'https://example.test/cover.jpg');
    expect(storage.deletedPaths, isEmpty);
  });

  test('deletes an uploaded cover when activity creation fails', () async {
    final repository = _ActivityRepository(failCreate: true);
    final storage = _CoverStorage();
    final creator = ActivityCreator(repository, storage);

    await expectLater(
      creator.create(_draft(), coverBytes: Uint8List.fromList([1, 2, 3])),
      throwsStateError,
    );

    expect(storage.deletedPaths, ['activity-covers/user-1/cover.jpg']);
  });

  test('does not upload when no cover was selected', () async {
    final repository = _ActivityRepository();
    final storage = _CoverStorage();

    await ActivityCreator(repository, storage).create(_draft());

    expect(storage.uploadCount, 0);
    expect(repository.created?.coverImageUrl, isNull);
  });
}

Activity _draft() => Activity(
  id: '',
  title: 'Padel after work',
  description: '',
  placeSuggestion: 'Central court',
  startAt: DateTime(2030),
  hostId: 'user-1',
  category: ActivityCategory.padel,
);

class _ActivityRepository implements ActivityRepository {
  _ActivityRepository({this.failCreate = false});

  final bool failCreate;
  Activity? created;

  @override
  Future<Activity> createActivity(Activity activity) async {
    if (failCreate) throw StateError('create failed');
    created = activity;
    return activity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CoverStorage implements ActivityCoverStorage {
  int uploadCount = 0;
  final List<String> deletedPaths = [];

  @override
  Future<StoredActivityCover> upload({
    required String userId,
    required Uint8List bytes,
  }) async {
    uploadCount++;
    return const StoredActivityCover(
      url: 'https://example.test/cover.jpg',
      path: 'activity-covers/user-1/cover.jpg',
    );
  }

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
  }
}
