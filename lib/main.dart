import 'package:flutter/material.dart';

import 'data/local_session_repository.dart';
import 'data/session_repository.dart';
import 'features/auth/application/google_auth_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/hub/data/event_repository.dart';
import 'features/hub/data/local_event_repository.dart';
import 'features/hub/presentation/hub_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'features/auth/data/google_sign_in_service.dart';
import 'features/settings/application/theme_controller.dart';
import 'features/settings/data/drive_service.dart';
import 'features/settings/data/local_backup_service.dart';
import 'core/presentation/no_transitions_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/config/google_oauth_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase initialization removed

  final prefs = await SharedPreferences.getInstance();
  final themeController = ThemeController(prefs);

  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.file'],
    serverClientId: GoogleOAuthConfig.webServerClientId,
  );

  final attendanceRepository = LocalJsonAttendanceRepository();
  final sessionRepository = LocalJsonSessionRepository();
  final eventRepository = LocalJsonEventRepository();

  final driveService = DriveService(
    googleSignIn: googleSignIn,
    attendanceRepository: attendanceRepository,
    sessionRepository: sessionRepository,
    eventRepository: eventRepository,
  );
  // Restore sync session and trigger initial sync if enabled
  driveService.init();

  final localBackupService = LocalBackupService();
  final googleAuthService = GoogleSignInAuthService(googleSignIn: googleSignIn);

  runApp(
    AttendanceApp(
      themeController: themeController,
      driveService: driveService,
      localBackupService: localBackupService,
      googleAuthService: googleAuthService,
      repository: attendanceRepository,
      sessionRepository: sessionRepository,
      eventRepository: eventRepository,
      disableAnimations: false,
    ),
  );
}

class AttendanceApp extends StatefulWidget {
  AttendanceApp({
    super.key,
    required this.themeController,
    AttendanceRepository? repository,
    SessionRepository? sessionRepository,
    EventRepository? eventRepository,
    this.authRepository,
    this.googleAuthService,
    this.driveService,
    this.localBackupService,
    this.disableAnimations = false,
  }) : repository = repository ?? LocalJsonAttendanceRepository(),
       sessionRepository = sessionRepository ?? LocalJsonSessionRepository(),
       eventRepository = eventRepository ?? LocalJsonEventRepository();

  final ThemeController themeController;
  final AttendanceRepository repository;
  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AuthRepository? authRepository;
  final GoogleAuthService? googleAuthService;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;
  final bool disableAnimations;

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Trigger sync when app is backgrounded or closed
      widget.driveService?.syncFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'Attendance',
          debugShowCheckedModeBanner: false,
          themeMode: widget.themeController.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'IBM Plex Sans',
            pageTransitionsTheme: PageTransitionsTheme(
              builders: widget.disableAnimations
                  ? {
                      for (var platform in TargetPlatform.values)
                        platform: const NoTransitionsBuilder(),
                    }
                  : {
                      TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
                      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
                      TargetPlatform.macOS: const FadeUpwardsPageTransitionsBuilder(),
                    },
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'IBM Plex Sans',
            pageTransitionsTheme: PageTransitionsTheme(
              builders: widget.disableAnimations
                  ? {
                      for (var platform in TargetPlatform.values)
                        platform: const NoTransitionsBuilder(),
                    }
                  : {
                      TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
                      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
                      TargetPlatform.macOS: const FadeUpwardsPageTransitionsBuilder(),
                    },
            ),
          ),
          home: HubPage(
            themeController: widget.themeController,
            sessionRepository: widget.sessionRepository,
            eventRepository: widget.eventRepository,
            attendanceRepository: widget.repository,
            driveService: widget.driveService,
            localBackupService: widget.localBackupService,
            disableAnimations: widget.disableAnimations,
          ),
        );
      },
    );
  }
}
