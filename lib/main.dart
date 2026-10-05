import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/config/app_config.dart';
import 'data/auth/auth_service.dart';
import 'data/auth/firebase_auth_service.dart';
import 'data/auth/mock_auth_service.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/circle_repository.dart';
import 'data/repositories/firestore_activity_repository.dart';
import 'data/repositories/firestore_chat_repository.dart';
import 'data/repositories/firestore_circle_repository.dart';
import 'data/repositories/firestore_friend_repository.dart';
import 'data/repositories/firestore_safety_repository.dart';
import 'data/repositories/firestore_user_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/mock_activity_repository.dart';
import 'data/repositories/mock_chat_repository.dart';
import 'data/repositories/mock_circle_repository.dart';
import 'data/repositories/mock_friend_repository.dart';
import 'data/repositories/mock_safety_repository.dart';
import 'data/repositories/mock_user_repository.dart';
import 'data/repositories/safety_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/storage/activity_cover_storage.dart';
import 'data/storage/firebase_activity_cover_storage.dart';
import 'data/storage/inline_activity_cover_storage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: choose implementations based on AppConfig.
  // Mock mode runs with zero backend; Firebase mode wires Firestore + Google
  // sign-in. The auth gate in [HangOutApp] decides sign-in vs. home.
  late final AnalyticsService analytics;
  late final AuthService authService;
  late final ActivityRepository repository;
  late final ChatRepository chatRepository;
  late final UserRepository userRepository;
  late final FriendRepository friendRepository;
  late final CircleRepository circleRepository;
  late final SafetyRepository safetyRepository;
  late final ActivityCoverStorage coverStorage;

  if (AppConfig.useMockBackend) {
    analytics = ConsoleAnalyticsService();
    coverStorage = InlineActivityCoverStorage();
    final mockUsers = MockUserRepository();
    userRepository = mockUsers;
    friendRepository = MockFriendRepository(mockUsers);
    authService = MockAuthService();
    repository = MockActivityRepository();
    chatRepository = MockChatRepository();
    circleRepository = MockCircleRepository(chatRepository);
    safetyRepository = MockSafetyRepository();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode && AppConfig.useFirebaseEmulators) {
      const host = AppConfig.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
    analytics = FirebaseAnalyticsService();
    coverStorage = FirebaseActivityCoverStorage();
    // Offline persistence: cache reads locally and queue writes (e.g. a like)
    // while offline, syncing automatically once connectivity returns.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    userRepository = FirestoreUserRepository();
    friendRepository = FirestoreFriendRepository();
    // Auth mirrors the signed-in profile into the users collection so other
    // members can see real names + photos.
    authService = FirebaseAuthService(userRepository: userRepository);
    repository = FirestoreActivityRepository();
    chatRepository = FirestoreChatRepository();
    circleRepository = FirestoreCircleRepository(chatRepository);
    safetyRepository = FirestoreSafetyRepository();
  }

  runApp(HangOutApp(
    authService: authService,
    repository: repository,
    chatRepository: chatRepository,
    userRepository: userRepository,
    friendRepository: friendRepository,
    circleRepository: circleRepository,
    safetyRepository: safetyRepository,
    analytics: analytics,
    coverStorage: coverStorage,
  ));
}
