import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import 'data/session.dart';
import 'data/session_repository.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/google_auth_service.dart';
import 'features/auth/config/google_oauth_config.dart';
import 'features/auth/data/local_auth_data_source.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'features/auth/data/local_auth_storage.dart';
import 'features/auth/data/google_sign_in_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/ai/ai_provider.dart';
import 'features/ai/ai_provider_factory.dart';
import 'features/ai/http_ai_provider.dart';
import 'features/ai/mock_ai_provider.dart';
import 'features/analytics/attendance_analytics.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/models/attendance_status.dart';
import 'features/attendance/models/family.dart';
import 'features/attendance/presentation/attendance_flow_page.dart';
import 'features/reports/report_export_page.dart';
import 'features/sessions/session_detail_page.dart';

void main() {
  runApp(AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  AttendanceApp({
    super.key,
    AttendanceRepository? repository,
    SessionRepository? sessionRepository,
    AiProvider? aiProvider,
    AiProviderFactory? aiFactory,
    AiProviderType providerType = AiProviderType.mock,
    bool aiEnabled = true,
    this.authRepository,
    this.authDirectoryProvider,
    this.googleAuthService,
  }) : repository = repository ?? LocalJsonAttendanceRepository(),
       sessionRepository =
           sessionRepository ??
           LocalSessionRepository(seedSessions: buildSeedSessions()),
       aiFactory = aiFactory ?? const AiProviderFactory(),
       providerType = providerType,
       aiEnabled = aiEnabled,
       aiProvider =
           aiProvider ??
           (aiFactory ?? const AiProviderFactory()).create(providerType);

  final AttendanceRepository repository;
  final SessionRepository sessionRepository;
  final AiProvider aiProvider;
  final AiProviderFactory aiFactory;
  final AiProviderType providerType;
  final bool aiEnabled;
  final AuthRepository? authRepository;
  final Future<Directory> Function()? authDirectoryProvider;
  final GoogleAuthService? googleAuthService;

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final AuthController _authController;
  late final GoogleAuthService _googleAuthService;

  @override
  void initState() {
    super.initState();
    final authDirectoryProvider =
        widget.authDirectoryProvider ?? getApplicationDocumentsDirectory;
    final authRepository =
        widget.authRepository ??
        LocalAuthRepository(
          LocalAuthDataSource(
            LocalAuthStorage(directoryProvider: authDirectoryProvider),
          ),
        );
    _googleAuthService =
        widget.googleAuthService ??
        GoogleSignInAuthService(
          googleSignIn: GoogleSignIn(
            clientId: GoogleOAuthConfig.iosClientId,
            serverClientId: GoogleOAuthConfig.androidServerClientId,
          ),
        );
    _authController = AuthController(
      repository: authRepository,
      googleAuthService: _googleAuthService,
    )..restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _authController,
      child: MaterialApp(
        title: 'Attendance Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: AuthGate(
          controller: _authController,
          homeBuilder: (context) => AttendanceHomePage(
            repository: widget.repository,
            sessionRepository: widget.sessionRepository,
            aiProvider: widget.aiProvider,
            aiFactory: widget.aiFactory,
            providerType: widget.providerType,
            aiEnabled: widget.aiEnabled,
            onSignOut: _authController.signOut,
          ),
        ),
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
  Future<List<AbsencePrediction>>? _predictionFuture;
  final Map<String, FollowUpSuggestion> _suggestedMessages = {};
  final Set<String> _loadingSubjects = {};
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
    _predictionFuture = null;
    _suggestedMessages.clear();
    _loadingSubjects.clear();
  }

  void _handleRangeChange(AnalyticsRange selection) {
    setState(() {
      _selectedRange = selection;
      _predictionFuture = null;
    });
  }

  void _applyProviderSelection(AiProviderType type) {
    setState(() {
      _providerType = type;
      _aiProvider = widget.aiFactory.create(
        type,
        endpointOverride: _endpointController.text,
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
      final suggestion = await _aiProvider.suggestFollowUp(
        FollowUpRequest(
          flag: flag,
          analytics: analytics,
          sessions: sessions,
          rangeLabel: analytics.range.label,
          family: _familyForFlag(flag, families),
        ),
      );

      if (!mounted) return;

      setState(() {
        _suggestedMessages[flag.subject] = suggestion;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Suggested message for ${flag.subject}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(suggestion.message),
              const SizedBox(height: 12),
              Text(
                suggestion.reasoning,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
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

  Future<List<AbsencePrediction>>? _obtainPredictionFuture(
    AttendanceAnalytics analytics,
    List<Session> sessions,
  ) {
    if (!_aiEnabled) return null;
    _predictionFuture ??= _aiProvider.predictAbsences(
      AbsencePredictionRequest(analytics: analytics, sessions: sessions),
    );
    return _predictionFuture;
  }

  Widget _buildAiSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI assistant',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Generate follow-ups and forecast risk.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _aiEnabled,
                  onChanged: (value) {
                    setState(() {
                      _aiEnabled = value;
                      if (!value) {
                        _resetAiInsights();
                      } else {
                        _predictionFuture = null;
                      }
                    });
                  },
                ),
              ],
            ),
            if (_aiEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AiProviderType>(
                      value: _providerType,
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
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _applyProviderSelection(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_providerType == AiProviderType.http)
                    Expanded(
                      child: TextFormField(
                        controller: _endpointController,
                        decoration: const InputDecoration(
                          labelText: 'Endpoint',
                          isDense: true,
                        ),
                        onFieldSubmitted: (_) =>
                            _applyProviderSelection(AiProviderType.http),
                      ),
                    ),
                ],
              ),
              if (_providerType == AiProviderType.http)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _applyProviderSelection(AiProviderType.http),
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Apply endpoint'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionPanel(
    Future<List<AbsencePrediction>>? predictionFuture,
  ) {
    if (!_aiEnabled) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Likely upcoming absences',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Icon(Icons.auto_graph),
              ],
            ),
            const SizedBox(height: 12),
            if (predictionFuture == null)
              Text(
                'Enable AI above to view absence forecasts.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              FutureBuilder<List<AbsencePrediction>>(
                future: predictionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Could not load predictions: ${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    );
                  }

                  final predictions = snapshot.data ?? [];
                  if (predictions.isEmpty) {
                    return Text(
                      'No high-risk absences detected in this window.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }

                  return Column(
                    children: predictions.take(4).map((prediction) {
                      final probabilityLabel =
                          '${(prediction.probability * 100).round()}% risk';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: prediction.isFamily
                              ? Colors.indigo.shade50
                              : Colors.amber.shade50,
                          child: Icon(
                            prediction.isFamily
                                ? Icons.family_restroom
                                : Icons.trending_up,
                            color: prediction.isFamily
                                ? Colors.indigo.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        title: Text(prediction.subject),
                        subtitle: Text(prediction.reason),
                        trailing: Text(
                          probabilityLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _startAttendanceFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceFlowPage(repository: widget.repository),
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
        final latestTrend = analytics.trend.isNotEmpty
            ? analytics.trend.last.toStringAsFixed(0)
            : '0';
        final predictionFuture = _obtainPredictionFuture(
          analytics,
          homeData.sessions,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Tracker'),
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
                  Text(
                    'Engagement overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rolling window',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            range.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      DropdownButton<AnalyticsRange>(
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Attendance rate',
                        value: '$attendanceRate%',
                        subtitle: '${breakdown.total} check-ins',
                        background: Colors.green.shade50,
                        accent: Colors.green.shade700,
                      ),
                      _StatCard(
                        title: 'Absences',
                        value: '${breakdown.absent}',
                        subtitle: maxAbsenceStreak == 0
                            ? 'No recent absences'
                            : 'Longest streak: $maxAbsenceStreak',
                        background: Colors.red.shade50,
                        accent: Colors.red.shade700,
                      ),
                      _StatCard(
                        title: 'Late arrivals',
                        value: '${breakdown.partial}',
                        subtitle: 'Latest trend $latestTrend%',
                        background: Colors.orange.shade50,
                        accent: Colors.orange.shade800,
                      ),
                      _StatCard(
                        title: 'Watchlist',
                        value: '${analytics.watchlist.length}',
                        subtitle: analytics.watchlist.isEmpty
                            ? 'All clear'
                            : 'Needs follow-up',
                        background: Colors.blue.shade50,
                        accent: Colors.blue.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAiSettings(),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Wellness watchlist',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Icon(
                                Icons.favorite_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (analytics.watchlist.isEmpty)
                            Text(
                              'No repeated misses detected in this window.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            FutureBuilder<List<AbsencePrediction>>(
                              future: predictionFuture,
                              builder: (context, snapshot) {
                                final predictionBySubject = {
                                  for (final prediction in snapshot.data ?? [])
                                    prediction.subject: prediction,
                                };
                                return Column(
                                  children: analytics.watchlist.map((flag) {
                                    final suggestion =
                                        _suggestedMessages[flag.subject];
                                    final prediction =
                                        predictionBySubject[flag.subject];
                                    final loading = _loadingSubjects.contains(
                                      flag.subject,
                                    );

                                    return ListTile(
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
                                      title: Text(flag.subject),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(flag.reason),
                                          if (prediction != null)
                                            Text(
                                              'AI risk: ${(prediction.probability * 100).round()}% likely absence',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
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
                                                  : () => _handleSuggestMessage(
                                                      flag: flag,
                                                      analytics: analytics,
                                                      sessions:
                                                          homeData.sessions,
                                                      families:
                                                          homeData.families,
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
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPredictionPanel(predictionFuture),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Drill-down insights',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                range.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
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
                        icon: Icons.person_add_alt_1,
                        label: 'Add attendee',
                        onPressed: () => _startAttendanceFlow(context),
                      ),
                      _ActionChipButton(
                        icon: Icons.bar_chart_outlined,
                        label: 'Export report',
                        onPressed: () => _openReports(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent sessions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _homeDataFuture = _loadHomeData();
                            _resetAiInsights();
                          });
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                            '${percent}%',
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
      breakdown.partial,
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
            buildBar('Late', breakdown.partial, Colors.orange.shade400),
            buildBar('Absent', breakdown.absent, Colors.red.shade400),
          ],
        ),
      ],
    );
  }
}

class _HomeData {
  const _HomeData({this.sessions = const [], this.families = const []});

  final List<Session> sessions;
  final List<Family> families;
}
