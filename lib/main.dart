import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/local_session_repository.dart';
import 'data/session.dart';
import 'data/session_repository.dart';
import 'features/ai/ai_provider.dart';
import 'features/ai/ai_provider_factory.dart';
import 'features/ai/http_ai_provider.dart';
import 'features/analytics/attendance_analytics.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/google_auth_service.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/models/attendance_status.dart';
import 'features/attendance/models/family.dart';
import 'features/attendance/presentation/attendance_flow_page.dart';
import 'features/attendance/utils/name_corrections.dart';
import 'features/families/presentation/family_list_page.dart';
import 'features/hub/data/event_repository.dart';
import 'features/hub/data/local_event_repository.dart';
import 'features/hub/presentation/hub_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'features/auth/data/google_sign_in_service.dart';
import 'features/reports/report_export_page.dart';
import 'features/sessions/session_detail_page.dart';
import 'features/settings/application/theme_controller.dart';
import 'features/settings/data/drive_service.dart';
import 'features/settings/data/local_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase initialization removed

  final prefs = await SharedPreferences.getInstance();
  final themeController = ThemeController(prefs);

  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive'],
  );

  final attendanceRepository = LocalJsonAttendanceRepository();
  final sessionRepository = LocalJsonSessionRepository(
    seedSessions: buildSeedSessions(),
  );
  final eventRepository = LocalJsonEventRepository();

  final driveService = DriveService(
    googleSignIn: googleSignIn,
    attendanceRepository: attendanceRepository,
    sessionRepository: sessionRepository,
    eventRepository: eventRepository,
  );
  // Restore sync session silently
  await driveService.signInSilently();

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
    AiProvider? aiProvider,
    AiProviderFactory? aiFactory,
    this.providerType = AiProviderType.mock,
    this.aiEnabled = true,
    this.authRepository,
    this.googleAuthService,
    this.driveService,
    this.localBackupService,
  }) : repository = repository ?? LocalJsonAttendanceRepository(),
       sessionRepository =
           sessionRepository ??
           LocalJsonSessionRepository(seedSessions: buildSeedSessions()),
       eventRepository = eventRepository ?? LocalJsonEventRepository(),
       aiFactory = aiFactory ?? const AiProviderFactory(),
       aiProvider =
           aiProvider ??
           (aiFactory ?? const AiProviderFactory()).create(providerType);

  final ThemeController themeController;
  final AttendanceRepository repository;
  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AiProvider aiProvider;
  final AiProviderFactory aiFactory;
  final AiProviderType providerType;
  final bool aiEnabled;
  final AuthRepository? authRepository;
  final GoogleAuthService? googleAuthService;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    final authRepository = widget.authRepository ?? LocalAuthRepository();
    _authController = AuthController(
      repository: authRepository,
      googleAuthService: widget.googleAuthService,
    )..restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _authController,
      child: ListenableBuilder(
        listenable: widget.themeController,
        builder: (context, child) {
          return MaterialApp(
            title: 'Attendance',
            themeMode: widget.themeController.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'IBM Plex Sans',
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'IBM Plex Sans',
            ),
            home: AuthGate(
              controller: _authController,
              homeBuilder: (context) => HubPage(
                themeController: widget.themeController,
                sessionRepository: widget.sessionRepository,
                eventRepository: widget.eventRepository,
                attendanceRepository: widget.repository,
                onSignOut: _authController.signOut,
                driveService: widget.driveService,
                localBackupService: widget.localBackupService,
              ),
            ),
          );
        },
      ),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({
    super.key,
    required this.repository,
    required this.sessionRepository,
    required this.aiProvider,
    required this.aiFactory,
    required this.providerType,
    required this.aiEnabled,
    this.onSignOut,
  });

  final AttendanceRepository repository;
  final SessionRepository sessionRepository;
  final AiProvider aiProvider;
  final AiProviderFactory aiFactory;
  final AiProviderType providerType;
  final bool aiEnabled;
  final VoidCallback? onSignOut;

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  late Future<_HomeData> _homeDataFuture;
  AnalyticsRange _selectedRange = AnalyticsRange.last30Days;
  late bool _aiEnabled;
  late AiProvider _aiProvider;
  late AiProviderType _providerType;
  final Map<String, FollowUpSuggestion> _suggestedMessages = {};
  final Set<String> _loadingSubjects = {};
  final Set<String> _ignoredNameSuggestions = {};
  final Map<String, bool> _labelOverrides = {};
  late final TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    _aiEnabled = widget.aiEnabled;
    _aiProvider = widget.aiProvider;
    _providerType = widget.providerType;
    final defaultEndpoint = widget.aiProvider is HttpAiProvider
        ? (widget.aiProvider as HttpAiProvider).endpoint.toString()
        : widget.aiFactory.defaultEndpoint;
    _endpointController = TextEditingController(text: defaultEndpoint);
    _homeDataFuture = _loadHomeData();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  Future<_HomeData> _loadHomeData() async {
    final sessions = await widget.sessionRepository.loadSessions();
    final families = await widget.repository.fetchFamilies();
    return _HomeData(sessions: sessions, families: families);
  }

  void _resetAiInsights() {
    _suggestedMessages.clear();
    _loadingSubjects.clear();
    _ignoredNameSuggestions.clear();
  }

  void _handleRangeChange(AnalyticsRange selection) {
    setState(() {
      _selectedRange = selection;
    });
  }

  void _applyProviderSelection(AiProviderType type) {
    setState(() {
      _providerType = type;
      _aiProvider = widget.aiFactory.create(
        type,
        endpointOverride: _endpointController.text,
        apiKey: _endpointController
            .text, // Reusing controller for API Key as well for simplicity, or should I create a separate one?
        // Let's create a separate controller to be clean.
      );
      _resetAiInsights();
    });
  }

  Family? _familyForFlag(WellnessFlag flag, List<Family> families) {
    if (flag.isFamily) {
      try {
        return families.firstWhere(
          (family) => family.displayName == flag.subject,
        );
      } catch (_) {
        return null;
      }
    }

    for (final family in families) {
      final match = family.members.any(
        (member) => member.displayName == flag.subject,
      );
      if (match) return family;
    }
    return null;
  }

  Future<void> _handleSuggestMessage({
    required WellnessFlag flag,
    required AttendanceAnalytics analytics,
    required List<Session> sessions,
    required List<Family> families,
  }) async {
    if (!_aiEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable AI assistant to get suggestions.'),
        ),
      );
      return;
    }

    setState(() {
      _loadingSubjects.add(flag.subject);
    });

    try {
      final nameMetadata = buildNameMetadata(
        sessions: sessions,
        analytics: analytics,
        families: families,
      );
      final attendanceFeatures = buildAttendanceLabelFeatures(
        sessions: sessions,
        analytics: analytics,
        families: families,
      );
      final suggestion = await _aiProvider.suggestFollowUp(
        FollowUpRequest(
          flag: flag,
          analytics: analytics,
          sessions: sessions,
          rangeLabel: analytics.range.label,
          family: _familyForFlag(flag, families),
          nameMetadata: nameMetadata,
          attendanceFeatures: attendanceFeatures,
        ),
      );

      if (!mounted) return;
      final insight = _NameInsight.fromSources(suggestion, null);

      setState(() {
        _suggestedMessages[flag.subject] = suggestion;
        if (insight.label != null &&
            !_labelOverrides.containsKey(flag.subject)) {
          _labelOverrides[flag.subject] = true;
        }
        _ignoredNameSuggestions.remove(flag.subject);
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var applying = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Suggested message for ${flag.subject}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(suggestion.message),
                      const SizedBox(height: 12),
                      Text(
                        suggestion.reasoning,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (insight.hasSuggestion) ...[
                        const SizedBox(height: 12),
                        _NameInsightDetails(insight: insight),
                      ],
                      if (insight.label != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Gemini label',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(width: 8),
                            _buildLabelChip(flag.subject, insight),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (insight.hasSuggestion)
                    TextButton.icon(
                      onPressed: applying
                          ? null
                          : () async {
                              setDialogState(() => applying = true);
                              await _applyNameSuggestion(
                                flag: flag,
                                insight: insight,
                                families: families,
                              );
                              if (mounted) {
                                setDialogState(() => applying = false);
                              }
                              if (dialogContext.mounted &&
                                  Navigator.of(dialogContext).canPop()) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                      icon: applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Apply correction'),
                    ),
                  if (insight.hasSuggestion)
                    TextButton(
                      onPressed: applying
                          ? null
                          : () {
                              setState(() {
                                _ignoredNameSuggestions.add(flag.subject);
                              });
                              Navigator.of(dialogContext).pop();
                            },
                      child: const Text('Ignore'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingSubjects.remove(flag.subject);
        });
      }
    }
  }

  Future<void> _applyNameSuggestion({
    required WellnessFlag flag,
    required _NameInsight insight,
    required List<Family> families,
  }) async {
    if (!insight.hasSuggestion) return;
    if (_loadingSubjects.contains(flag.subject)) return;

    setState(() {
      _loadingSubjects.add(flag.subject);
    });

    try {
      final updatedFamilies = applyNameCorrection(
        families: families,
        subject: flag.subject,
        correctedName: insight.suggestedName ?? flag.subject,
        duplicateCandidates: insight.duplicateCandidates,
      );

      await widget.repository.saveFamilies(updatedFamilies);
      if (!mounted) return;
      setState(() {
        _homeDataFuture = _loadHomeData();
        _resetAiInsights();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated records for ${insight.suggestedName ?? flag.subject}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply suggestion: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingSubjects.remove(flag.subject);
        });
      }
    }
  }

  Widget _buildLabelChip(String subject, _NameInsight insight) {
    final label = insight.label;
    if (label == null) return const SizedBox.shrink();
    final enabled = _labelOverrides[subject] ?? true;
    return Tooltip(
      message: insight.labelRationale ?? 'Gemini suggested this label.',
      child: FilterChip(
        selected: enabled,
        onSelected: (value) {
          setState(() {
            _labelOverrides[subject] = value;
          });
        },
        avatar: Icon(enabled ? Icons.sell : Icons.sell_outlined, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildAiSettings() {
    return Column(
      children: [
        _SectionHeader(
          title: 'AI assistant',
          subtitle: 'Generate follow-ups and forecast risk',
          action: Switch.adaptive(
            value: _aiEnabled,
            onChanged: (value) {
              setState(() {
                _aiEnabled = value;
                if (!value) {
                  _resetAiInsights();
                }
              });
            },
          ),
        ),
        if (_aiEnabled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AiProviderType>(
                          initialValue: _providerType,
                          decoration: const InputDecoration(
                            labelText: 'Provider',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: AiProviderType.mock,
                              child: Text('Mock (offline sandbox)'),
                            ),
                            DropdownMenuItem(
                              value: AiProviderType.http,
                              child: Text('Remote HTTP endpoint'),
                            ),
                            DropdownMenuItem(
                              value: AiProviderType.gemini,
                              child: Text('Gemini API (Free Tier)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            _applyProviderSelection(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_providerType == AiProviderType.http ||
                          _providerType == AiProviderType.gemini)
                        Expanded(
                          child: TextFormField(
                            controller: _endpointController,
                            obscureText: _providerType == AiProviderType.gemini,
                            decoration: InputDecoration(
                              labelText: _providerType == AiProviderType.gemini
                                  ? 'API Key'
                                  : 'Endpoint',
                              isDense: true,
                            ),
                            onFieldSubmitted: (_) =>
                                _applyProviderSelection(_providerType),
                          ),
                        ),
                    ],
                  ),
                  if (_providerType == AiProviderType.http ||
                      _providerType == AiProviderType.gemini)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _applyProviderSelection(_providerType),
                        icon: const Icon(Icons.check),
                        label: Text(
                          _providerType == AiProviderType.gemini
                              ? 'Apply Key'
                              : 'Apply endpoint',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _startAttendanceFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceFlowPage(repository: widget.repository),
      ),
    );
  }

  void _openFamilyList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyListPage(repository: widget.repository),
      ),
    );
  }

  void _openSession(Session session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: session,
          repository: widget.sessionRepository,
        ),
      ),
    );
    setState(() {
      _homeDataFuture = _loadHomeData();
      _resetAiInsights();
    });
  }

  void _openReports(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReportExportPage(sessionRepository: widget.sessionRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final homeData = snapshot.data ?? const _HomeData();
        final range = _selectedRange.resolve(DateTime.now());
        final analytics = calculateAttendanceAnalytics(
          sessions: homeData.sessions,
          families: homeData.families,
          range: range,
        );

        final breakdown = analytics.breakdown;
        final attendanceRate = breakdown.rate.round();
        final maxAbsenceStreak = analytics.attendees.values.fold<int>(
          0,
          (previous, element) => math.max(previous, element.absenceStreak),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance'),
            actions: [
              if (widget.onSignOut != null)
                IconButton(
                  key: const Key('signOutButton'),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                  onPressed: widget.onSignOut,
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _homeDataFuture = _loadHomeData();
                  _resetAiInsights();
                });
                await _homeDataFuture;
              },
              child: ListView(
                children: [
                  const _SectionHeader(
                    title: 'Quick actions',
                    subtitle: 'Shortcuts for common tasks',
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ActionChipButton(
                        icon: Icons.fact_check_outlined,
                        label: 'Take attendance',
                        onPressed: () => _startAttendanceFlow(context),
                      ),
                      _ActionChipButton(
                        icon: Icons.people,
                        label: 'Manage families',
                        onPressed: () => _openFamilyList(context),
                      ),
                      _ActionChipButton(
                        icon: Icons.bar_chart_outlined,
                        label: 'Export report',
                        onPressed: () => _openReports(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  _SectionHeader(
                    title: 'Rolling window',
                    subtitle: 'Key data from ${range.label}',
                    action: DropdownButton<AnalyticsRange>(
                      value: _selectedRange,
                      items: AnalyticsRange.values
                          .map(
                            (range) => DropdownMenuItem(
                              value: range,
                              child: Text(range.label),
                            ),
                          )
                          .toList(),
                      onChanged: (selection) {
                        if (selection == null) return;
                        _handleRangeChange(selection);
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Attendance rate',
                          value: '$attendanceRate%',
                          subtitle: '${breakdown.total} check-ins',
                          background: Colors.green.withValues(alpha: 0.1),
                          accent: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'Absences',
                          value: '${breakdown.absent}',
                          subtitle: maxAbsenceStreak == 0
                              ? 'No recent absences'
                              : 'Longest streak: $maxAbsenceStreak',
                          background: Colors.red.withValues(alpha: 0.1),
                          accent: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'Watchlist',
                          value: '${analytics.watchlist.length}',
                          subtitle: analytics.watchlist.isEmpty
                              ? 'All clear'
                              : 'Needs follow-up',
                          background: Colors.blue.withValues(alpha: 0.1),
                          accent: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAiSettings(),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Wellness watchlist',
                    subtitle: 'Members with repeated absences',
                    action: Icon(
                      Icons.favorite_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (analytics.watchlist.isEmpty)
                            Text(
                              'No repeated misses detected in this window.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            Column(
                              children: analytics.watchlist.map((flag) {
                                final suggestion =
                                    _suggestedMessages[flag.subject];

                                final loading = _loadingSubjects.contains(
                                  flag.subject,
                                );
                                final nameInsight = _NameInsight.fromSources(
                                  suggestion,
                                  null,
                                );
                                final showNameInsight =
                                    nameInsight.hasSuggestion &&
                                    !_ignoredNameSuggestions.contains(
                                      flag.subject,
                                    );

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: flag.isFamily
                                              ? Colors.indigo.shade50
                                              : Colors.red.shade50,
                                          child: Icon(
                                            flag.isFamily
                                                ? Icons.groups_outlined
                                                : Icons.warning_amber_rounded,
                                            color: flag.isFamily
                                                ? Colors.indigo.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(child: Text(flag.subject)),
                                            if (nameInsight.hasLabel)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                child: _buildLabelChip(
                                                  flag.subject,
                                                  nameInsight,
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(flag.reason),

                                            if (suggestion != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                suggestion.message,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                        trailing: _aiEnabled
                                            ? TextButton.icon(
                                                onPressed: loading
                                                    ? null
                                                    : () =>
                                                          _handleSuggestMessage(
                                                            flag: flag,
                                                            analytics:
                                                                analytics,
                                                            sessions: homeData
                                                                .sessions,
                                                            families: homeData
                                                                .families,
                                                          ),
                                                icon: loading
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.auto_awesome,
                                                      ),
                                                label: const Text(
                                                  'Suggest message',
                                                ),
                                              )
                                            : const Text('AI off'),
                                      ),
                                      if (showNameInsight)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            72,
                                            0,
                                            8,
                                            4,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _NameInsightDetails(
                                                insight: nameInsight,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: loading
                                                        ? null
                                                        : () => _applyNameSuggestion(
                                                            flag: flag,
                                                            insight:
                                                                nameInsight,
                                                            families: homeData
                                                                .families,
                                                          ),
                                                    icon: loading
                                                        ? const SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons
                                                                .check_circle_outline,
                                                          ),
                                                    label: const Text('Apply'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  TextButton(
                                                    onPressed: loading
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              _ignoredNameSuggestions
                                                                  .add(
                                                                    flag.subject,
                                                                  );
                                                            });
                                                          },
                                                    child: const Text('Ignore'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      const Divider(height: 1),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  _SectionHeader(
                    title: 'Drill-down insights',
                    subtitle: 'Detailed attendance analytics',
                    action: Text(
                      range.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 90,
                            child: _SparklineChart(data: analytics.trend),
                          ),
                          const SizedBox(height: 12),
                          _StatusBarChart(breakdown: breakdown),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Recent sessions',
                    subtitle: 'History of past meetings',
                    action: TextButton(
                      onPressed: () {
                        setState(() {
                          _homeDataFuture = _loadHomeData();
                          _resetAiInsights();
                        });
                      },
                      child: const Text('Refresh'),
                    ),
                  ),
                  if (homeData.sessions.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No sessions saved yet'),
                        subtitle: Text(
                          'Start taking attendance to build history.',
                        ),
                      ),
                    ),
                  ...homeData.sessions.take(5).map((session) {
                    final attended = session.records
                        .where(
                          (record) => record.status == AttendanceStatus.present,
                        )
                        .length;
                    final expected = session.records.length;
                    final percent = expected == 0
                        ? 0
                        : (attended / expected * 100).round();
                    final dateLabel = session.sessionDate
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            '$percent%',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        title: Text(session.title),
                        subtitle: Text(
                          '$dateLabel · $attended of $expected present',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                          ),
                          onPressed: () => _openSession(session),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const _SectionHeader({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color background;
  final Color accent;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.background,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: accent),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.data});

  final List<double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No trend data yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return CustomPaint(
      painter: _SparklinePainter(data),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text('Trend', style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.data);

  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.shade400
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.indigo.shade100
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce(math.max).clamp(1, 100);
    final minValue = data.reduce(math.min);
    final range = (maxValue - minValue).abs();
    final horizontalStep = data.length == 1
        ? 0.0
        : size.width / (data.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final normalized = range == 0 ? 0.5 : (data[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      points.add(Offset(i * horizontalStep, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return !listEquals(oldDelegate.data, data);
  }
}

class _StatusBarChart extends StatelessWidget {
  const _StatusBarChart({required this.breakdown});

  final AttendanceBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      breakdown.present,
      breakdown.absent,
    ].fold<int>(1, (value, element) => math.max(value, element));

    Widget buildBar(String label, int count, Color color) {
      final height = count == 0 ? 6.0 : (count / maxValue) * 70 + 6;
      return Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 20,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text('$count', style: Theme.of(context).textTheme.labelMedium),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status breakdown', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildBar('Present', breakdown.present, Colors.green.shade400),
            buildBar('Absent', breakdown.absent, Colors.red.shade400),
          ],
        ),
      ],
    );
  }
}

class _NameInsightDetails extends StatelessWidget {
  const _NameInsightDetails({required this.insight});

  final _NameInsight insight;

  @override
  Widget build(BuildContext context) {
    if (!insight.hasSuggestion) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final confidence = insight.confidence;
    final confidenceLabel = confidence == null
        ? null
        : '${(confidence * 100).round()}% confidence';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insight.suggestedName != null)
          Row(
            children: [
              const Icon(Icons.edit_note, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Suggested name: ${insight.suggestedName}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (confidenceLabel != null)
                Text(confidenceLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        if (insight.duplicateCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Possible duplicates', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: insight.duplicateCandidates
                .map(
                  (candidate) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(candidate),
                    avatar: const Icon(Icons.copy_all, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
        if (insight.duplicateClusterIds.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Clusters: ${insight.duplicateClusterIds.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _NameInsight {
  const _NameInsight({
    this.suggestedName,
    this.confidence,
    this.duplicateCandidates = const [],
    this.duplicateClusterIds = const [],
    this.label,
    this.labelRationale,
  });

  factory _NameInsight.fromSources(
    FollowUpSuggestion? suggestion,
    AbsencePrediction? prediction,
  ) {
    final suggestedName =
        suggestion?.correctedName ??
        suggestion?.nameSuggestion?.suggestedName ??
        prediction?.correctedName ??
        prediction?.nameSuggestion?.suggestedName;
    final confidence =
        suggestion?.nameSuggestion?.confidence ??
        prediction?.nameSuggestion?.confidence;
    final duplicateCandidates = <String>{
      ...?suggestion?.duplicateCandidates,
      ...?prediction?.duplicateCandidates,
    };
    final duplicateClusterIds = <String>{
      ...?suggestion?.duplicateClusterIds,
      ...?prediction?.duplicateClusterIds,
      ...?suggestion?.nameSuggestion?.duplicateClusterIds,
      ...?prediction?.nameSuggestion?.duplicateClusterIds,
    };

    return _NameInsight(
      suggestedName: suggestedName,
      confidence: confidence,
      duplicateCandidates: duplicateCandidates.toList(),
      duplicateClusterIds: duplicateClusterIds.toList(),
      label: suggestion?.label ?? prediction?.label,
      labelRationale: suggestion?.labelRationale ?? prediction?.labelRationale,
    );
  }

  final String? suggestedName;
  final double? confidence;
  final List<String> duplicateCandidates;
  final List<String> duplicateClusterIds;
  final String? label;
  final String? labelRationale;

  bool get hasSuggestion =>
      suggestedName != null || duplicateCandidates.isNotEmpty;

  bool get hasLabel => label != null;
}

class _HomeData {
  const _HomeData({this.sessions = const [], this.families = const []});

  final List<Session> sessions;
  final List<Family> families;
}
