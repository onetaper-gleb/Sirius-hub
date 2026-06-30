// Models
import 'package:client/data/repository/repository.dart';
import 'package:client/data/source/source.dart';
import 'package:client/domain/bloc/forum/forum_controller.dart';
import 'package:flutter/services.dart';
import 'core/dependencies.dart';
import 'domain/bloc/auth/auth_bloc.dart';
import 'domain/bloc/auth/auth_event.dart';
import 'domain/bloc/forum/forum_event.dart';
import 'domain/bloc/news/news_bloc.dart';
import 'domain/bloc/schedule/schedule_bloc.dart';
import 'network/http_client.dart';

// Internal packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

// Screens
import 'module/auth/auth_gate.dart';

// Utils
import 'utils/firebase_options.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final dio = createAppHttpClient();

  // FireBase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final fireBaseAuth = firebase.FirebaseAuth.instance;

  final authDataSource = FirebaseAuthDataSource(auth: fireBaseAuth);

  // FireStore initialization
  final fireStore = FirebaseFirestore.instance;

  final userFireStore = UserFirestoreDataSource(firestore: fireStore);

  // Initializing repos
  final authRepository = AuthRepository(
    dio: dio,
    authDataSource: authDataSource,
    firestoreDataSource: userFireStore,
  );

  final newsRepository = NewsRepository(
    dio: dio,
    authDataSource: authDataSource,
  );

  final scheduleRepository = ScheduleRepository(dio: dio);

  final topicRepository = TopicRepository(
    dio: dio,
    authDataSource: authDataSource,
  );

  final forumRepository = ForumRepository(
    dio: dio,
    authDataSource: authDataSource,
  );

  final Dependencies dependencies = Dependencies(
    authRepository: authRepository,
    newsRepository: newsRepository,
    scheduleRepository: scheduleRepository,
    forumRepository: forumRepository,
    topicRepository: topicRepository,
  );

  runApp(
    DependenciesScope(
      dependencies: dependencies,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ScheduleBloc(
              scheduleRepository: dependencies.scheduleRepository,
            ),
          ),
          BlocProvider(
            create: (_) =>
                AuthBloc(authRepository: dependencies.authRepository)
                  ..add(AuthSubscriptionRequested()),
          ),
          BlocProvider(
            create: (_) =>
                NewsBloc(newsRepository: dependencies.newsRepository),
          ),
          BlocProvider(
            create: (_) =>
                ForumBloc(repository: dependencies.forumRepository)
                  ..add(ForumLoadRequested()),
          ),
        ],
        child: MyApp(),
      ),
    ),
  );

  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
