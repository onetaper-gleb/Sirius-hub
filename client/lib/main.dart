// Models
import 'package:client/data/repository/repository.dart';
import 'package:client/data/source/source.dart';
import 'package:flutter/services.dart';
import 'core/dependencies.dart';
import 'core/api_config.dart';
import 'package:flutter/foundation.dart';
import 'domain/bloc/auth/auth_bloc.dart';
import 'domain/bloc/auth/auth_event.dart';
import 'domain/bloc/theme/theme_bloc.dart';
import 'domain/bloc/theme/theme_event.dart';
import 'network/http_client.dart';

// Internal packages
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/data/local/app_database.dart';
import 'package:client/data/local/local_settings.dart';

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

  ApiConfig.validate(debug: kDebugMode);
  final AuthDataSource authDataSource;
  if (ApiConfig.authBackend == 'jwt') {
    final jwt = JwtAuthDataSource(
      dio: dio,
      tokenStore: const SecureSessionTokenStore(),
    );
    await jwt.restoreSession();
    authDataSource = jwt;
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    authDataSource = FirebaseAuthDataSource(
      auth: firebase.FirebaseAuth.instance,
    );
  }

  // Initializing repos
  final authRepository = AuthRepository(
    dio: dio,
    authDataSource: authDataSource,
  );

  final newsRepository = NewsRepository(
    dio: dio,
    authDataSource: authDataSource,
  );

  final prefs = await SharedPreferences.getInstance();

  final scheduleRepository = ScheduleRepository(
    dio: dio,
    db: AppDatabase(),
    localSettings: LocalSettings(prefs),
  );

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
            create: (_) =>
                AuthBloc(authRepository: dependencies.authRepository)
                  ..add(AuthSubscriptionRequested()),
          ),
          BlocProvider(create: (_) => ThemeBloc()..add(LoadTheme())),
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
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, mode) {
        return MaterialApp(
          title: 'CampHub',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}
