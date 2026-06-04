import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/config/app_config.dart';
import 'data/auth/auth_service.dart';
import 'data/auth/firebase_auth_service.dart';
import 'data/auth/mock_auth_service.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/firestore_activity_repository.dart';
import 'data/repositories/firestore_chat_repository.dart';
import 'data/repositories/firestore_user_repository.dart';
import 'data/repositories/mock_activity_repository.dart';
import 'data/repositories/mock_chat_repository.dart';
import 'data/repositories/mock_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: choose implementations based on AppConfig.
  // Mock mode runs with zero backend; Firebase mode wires Firestore + Google
  // sign-in. The auth gate in [HangOutApp] decides sign-in vs. home.
  final AnalyticsService analytics = ConsoleAnalyticsService();

  late final AuthService authService;
  late final ActivityRepository repository;
  late final ChatRepository chatRepository;
  late final UserRepository userRepository;

  if (AppConfig.useMockBackend) {
    userRepository = MockUserRepository();
    authService = MockAuthService();
    repository = MockActivityRepository();
    chatRepository = MockChatRepository();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Offline persistence: cache reads locally and queue writes (e.g. a like)
    // while offline, syncing automatically once connectivity returns.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    userRepository = FirestoreUserRepository();
    // Auth mirrors the signed-in profile into the users collection so other
    // members can see real names + photos.
    authService = FirebaseAuthService(userRepository: userRepository);
    repository = FirestoreActivityRepository();
    chatRepository = FirestoreChatRepository();
  }

  runApp(HangOutApp(
    authService: authService,
    repository: repository,
    chatRepository: chatRepository,
    userRepository: userRepository,
    analytics: analytics,
  ));
}
