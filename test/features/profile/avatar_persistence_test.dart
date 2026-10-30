import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/core/notifications/reminder_scheduler.dart';
import 'package:hangout/core/notifications/reminder_service.dart';
import 'package:hangout/core/widgets/image_pick.dart';
import 'package:hangout/core/widgets/cover_image.dart';
import 'package:hangout/data/auth/auth_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/activity_repository.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/data/repositories/user_repository.dart';
import 'package:hangout/domain/models/app_user.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/host_stats.dart';
import 'package:hangout/features/profile/profile_screen.dart';
import 'package:hangout/features/profile/widgets/avatar_drop_zone.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';

class _Users extends MockUserRepository {
  bool fail = false;

  @override
  Future<void> upsertProfile(AppUser user) async {
    if (fail) throw StateError('offline');
    await super.upsertProfile(user);
  }
}

class _Activities extends MockActivityRepository {
  @override
  Future<List<Activity>> fetchMyActivities(String userId) async => [];

  @override
  Future<HostStats> hostStats(String hostId) async => const HostStats();
}

void main() {
  const uid = MockAuthService.mockUserId;
  late _Users users;
  late String photo;

  setUp(() {
    rootBundle.clear();
    users = _Users();
    photo =
        'data:image/png;base64,${base64Encode(image.encodePng(image.Image(width: 2, height: 2)))}';
  });

  Future<void> show(WidgetTester t) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => MockAuthService()),
          Provider<UserRepository>.value(value: users),
          Provider<ActivityRepository>(create: (_) => _Activities()),
          Provider<AnalyticsService>(create: (_) => ConsoleAnalyticsService()),
          ChangeNotifierProvider<ReminderService>(
            create: (_) => ReminderService(NoopReminderScheduler()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('en', 'US')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ProfileScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('selected avatar is saved and restored on reopening Profile', (
    t,
  ) async {
    await show(t);
    t.widget<AvatarDropZone>(find.byType(AvatarDropZone)).onChanged(photo);
    await t.pumpAndSettle();
    expect((await users.fetchProfile(uid))!.avatarUrl, photo);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await show(t);
    expect(
      t.widget<AvatarDropZone>(find.byType(AvatarDropZone)).dataUrl,
      photo,
    );
  });

  testWidgets('failed avatar save rolls back preview and shows an error', (
    t,
  ) async {
    users.fail = true;
    await show(t);
    t.widget<AvatarDropZone>(find.byType(AvatarDropZone)).onChanged(photo);
    await t.pumpAndSettle();
    expect(
      t.widget<AvatarDropZone>(find.byType(AvatarDropZone)).dataUrl,
      isNull,
    );
    expect(
      find.text(
        "Couldn't save your profile. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect((await users.fetchProfile(uid))!.avatarUrl, isNull);
  });

  test('sign-in identity sync does not overwrite a saved avatar', () async {
    await users.upsertProfile(
      AppUser(id: uid, displayName: 'Rares', avatarUrl: photo),
    );
    await users.upsertIdentity(uid, displayName: 'Rares', avatarUrl: null);
    expect((await users.fetchProfile(uid))!.avatarUrl, photo);
  });

  test(
    'avatar decorations support saved photos and external account photos',
    () {
      expect(CoverImage.providerFor(photo), isA<MemoryImage>());
      expect(
        CoverImage.providerFor('https://example.com/avatar.jpg'),
        isA<NetworkImage>(),
      );
      expect(
        () => CoverImage.providerFor('data:image/jpeg;base64,invalid'),
        throwsFormatException,
      );
    },
  );

  test('avatar encoding bounds dimensions and base64 document size', () async {
    final bytes = image.encodePng(image.Image(width: 1800, height: 1200));
    final url = await avatarDataUrl(bytes);
    final encoded = base64Decode(url.split(',').last);
    final decoded = image.decodeJpg(encoded)!;
    expect(decoded.width, 512);
    expect(decoded.height, 512);
    expect(encoded.length, lessThanOrEqualTo(256 * 1024));
    expect(url.length, lessThan(350 * 1024));
  });
}
