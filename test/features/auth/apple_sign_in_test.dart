import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/data/account/account_deletion_service.dart';
import 'package:hangout/data/auth/auth_service.dart';
import 'package:hangout/data/auth/firebase_auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_circle_repository.dart';
import 'package:hangout/data/repositories/mock_friend_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/domain/models/app_user.dart';
import 'package:hangout/features/auth/sign_in_screen.dart';
import 'package:provider/provider.dart';

const _uid = 'apple-user';

class _Auth extends AuthService {
  _Auth({this.appleError, this.prepareError});

  final Object? appleError;
  final Object? prepareError;
  final calls = <String>[];

  @override
  String? get currentUserId => _uid;
  @override
  String? get displayName => null;
  @override
  String? get photoUrl => null;
  @override
  Future<void> signInWithGoogle() async => calls.add('google');
  @override
  Future<void> signInWithApple() async {
    calls.add('apple');
    if (appleError != null) throw appleError!;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<void> prepareAccountDeletion() async {
    calls.add('prepare');
    if (prepareError != null) throw prepareError!;
  }

  @override
  Future<void> deleteAccount() async => calls.add('deleteAccount');
}

class _Users extends MockUserRepository {
  _Users(this.log);
  final List<String> log;

  @override
  Future<AppUser?> fetchProfile(String id) {
    log.add('fetchProfile');
    return super.fetchProfile(id);
  }
}

void main() {
  group('identity mirroring keeps an existing name', () {
    test('an empty name from a repeat Apple sign-in does not wipe it',
        () async {
      final users = MockUserRepository();
      await users.upsertIdentity(_uid, displayName: 'Ana Pop');
      await users.upsertIdentity(_uid, displayName: '');
      expect((await users.fetchProfile(_uid))!.displayName, 'Ana Pop');
    });

    test('a non-empty name still updates it', () async {
      final users = MockUserRepository();
      await users.upsertIdentity(_uid, displayName: 'Ana Pop');
      await users.upsertIdentity(_uid, displayName: 'Ana Ionescu');
      expect((await users.fetchProfile(_uid))!.displayName, 'Ana Ionescu');
    });
  });

  group('account deletion', () {
    AccountDeletionService service(_Auth auth, _Users users) {
      final chats = MockChatRepository();
      return AccountDeletionService(
        authService: auth,
        activityRepository: MockActivityRepository(),
        chatRepository: chats,
        circleRepository: MockCircleRepository(chats),
        friendRepository: MockFriendRepository(users),
        userRepository: users,
      );
    }

    test('Apple confirmation runs before any data is touched', () async {
      final log = <String>[];
      final auth = _Auth();
      final users = _Users(log);
      await users.upsertIdentity(_uid, displayName: 'Ana');

      await service(auth, users).deleteAccountAndData(_uid);

      expect(auth.calls.first, 'prepare');
      expect(auth.calls.last, 'deleteAccount');
      expect(log, contains('fetchProfile'));
    });

    test('cancelling the Apple confirmation deletes nothing', () async {
      final log = <String>[];
      final auth = _Auth(prepareError: const SignInCancelled());
      final users = _Users(log);
      await users.upsertIdentity(_uid, displayName: 'Ana');

      await expectLater(
        service(auth, users).deleteAccountAndData(_uid),
        throwsA(isA<SignInCancelled>()),
      );

      expect(auth.calls, ['prepare']);
      expect(log, isEmpty);
      expect((await users.fetchProfile(_uid))!.displayName, 'Ana');
    });
  });

  group('FirebaseAuthService helpers', () {
    test('Google sign-out only for Google-linked accounts', () {
      expect(FirebaseAuthService.shouldSignOutOfGoogle(['google.com']), isTrue);
      expect(FirebaseAuthService.shouldSignOutOfGoogle(['apple.com']), isFalse);
      expect(FirebaseAuthService.shouldSignOutOfGoogle([]), isFalse);
    });

    test('Apple cancel codes are recognised', () {
      expect(FirebaseAuthService.isCancelCode('canceled'), isTrue);
      expect(FirebaseAuthService.isCancelCode('web-context-canceled'), isTrue);
      expect(FirebaseAuthService.isCancelCode('failed'), isFalse);
    });
  });

  group('sign-in screen', () {
    setUp(rootBundle.clear);

    Future<void> show(WidgetTester t, _Auth auth) async {
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            Provider<AnalyticsService>(
              create: (_) => ConsoleAnalyticsService(),
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
            home: SignInScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('iOS shows Apple first, and it signs in with Apple',
        (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final auth = _Auth();
        await show(t, auth);
        final apple = find.text('Continue with Apple');
        final google = find.text('Continue with Google');
        expect(apple, findsOneWidget);
        expect(t.getTopLeft(apple).dy, lessThan(t.getTopLeft(google).dy));

        await t.tap(apple);
        await t.pumpAndSettle();
        expect(auth.calls, ['apple']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android shows only Google', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await show(t, _Auth());
        expect(find.text('Continue with Apple'), findsNothing);
        expect(find.text('Continue with Google'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('cancelling Apple shows no error', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await show(t, _Auth(appleError: const SignInCancelled()));
        await t.tap(find.text('Continue with Apple'));
        await t.pumpAndSettle();
        expect(find.text("Couldn't sign in. Please try again."), findsNothing);
        expect(find.text('Continue with Apple'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an email already on Google says to use Google', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await show(
          t,
          _Auth(appleError: const AccountExistsWithOtherProvider()),
        );
        await t.tap(find.text('Continue with Apple'));
        await t.pumpAndSettle();
        expect(
          find.text(
            'This email is already registered with Google. '
            'Please continue with Google.',
          ),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
