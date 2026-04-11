import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'features/auth/account_screen.dart';
import 'features/auth/session_repository.dart';
import 'features/capture_screen.dart';
import 'features/home/home_screen.dart';
import 'features/insight_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/review_session_screen.dart';
import 'features/sync_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlowthApp());
}

class PlowthApp extends StatefulWidget {
  const PlowthApp({super.key});

  @override
  State<PlowthApp> createState() => _PlowthAppState();
}

class _PlowthAppState extends State<PlowthApp> {
  late final SessionRepository _sessionRepository;

  AppLaunchState? _launchState;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSubmittingAuthRequest = false;

  @override
  void initState() {
    super.initState();
    _sessionRepository = SessionRepository();
    SessionRepository.sessionInvalidated.addListener(_handleSessionInvalidated);
    _loadLaunchState();
  }

  @override
  void dispose() {
    SessionRepository.sessionInvalidated.removeListener(
      _handleSessionInvalidated,
    );
    super.dispose();
  }

  Future<void> _loadLaunchState() async {
    try {
      final launchState = await _sessionRepository.loadLaunchState();
      if (!mounted) {
        return;
      }

      setState(() {
        _launchState = launchState;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Failed to load the local session state.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGuestSessionStart(String learningGoal) async {
    await _runSessionMutation(
      action:
          () =>
              _sessionRepository.createGuestSession(learningGoal: learningGoal),
      fallbackMessage: 'Guest session setup failed unexpectedly.',
    );
  }

  Future<void> _handleRegister({
    required String learningGoal,
    required String email,
    required String password,
    String? name,
  }) async {
    await _runSessionMutation(
      action:
          () => _sessionRepository.register(
            learningGoal: learningGoal,
            email: email,
            password: password,
            name: name,
          ),
      fallbackMessage: 'Account registration failed unexpectedly.',
    );
  }

  Future<void> _handleLogin({
    required String email,
    required String password,
  }) async {
    await _runSessionMutation(
      action: () => _sessionRepository.login(email: email, password: password),
      fallbackMessage: 'Login failed unexpectedly.',
    );
  }

  Future<void> _runSessionMutation({
    required Future<void> Function() action,
    required String fallbackMessage,
  }) async {
    setState(() {
      _isSubmittingAuthRequest = true;
      _errorMessage = null;
    });

    try {
      await action();
      final launchState = await _sessionRepository.loadLaunchState();
      if (!mounted) {
        return;
      }

      setState(() {
        _launchState = launchState;
      });
    } on SessionException catch (error) {
      if (!mounted) {
        rethrow;
      }

      setState(() {
        _errorMessage = error.message;
      });
      rethrow;
    } catch (_) {
      final sessionError = SessionException(fallbackMessage);
      if (!mounted) {
        throw sessionError;
      }

      setState(() {
        _errorMessage = fallbackMessage;
      });
      throw sessionError;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingAuthRequest = false;
        });
      }
    }
  }

  Future<void> _handleSessionInvalidated() async {
    try {
      final launchState = await _sessionRepository.loadLaunchState();
      if (!mounted) {
        return;
      }
      setState(() {
        _launchState = launchState;
        _errorMessage =
            'Your session expired. Sign in or start a new guest session.';
        _isLoading = false;
        _isSubmittingAuthRequest = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _launchState = null;
        _errorMessage =
            'Your session expired. Sign in or start a new guest session.';
        _isLoading = false;
        _isSubmittingAuthRequest = false;
      });
    }
  }

  Future<void> _refreshLaunchState() async {
    await _loadLaunchState();
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plowth',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const _StatusScreen(
        key: ValueKey('loading'),
        title: 'Preparing Plowth',
        message: 'Loading local session and onboarding state.',
        icon: Icons.hourglass_top_rounded,
      );
    }

    if (_launchState?.hasSession ?? false) {
      return MainShell(
        key: const ValueKey('main-shell'),
        learningGoalLabel: SessionRepository.describeLearningGoal(
          _launchState?.learningGoal,
        ),
        sessionRepository: _sessionRepository,
        onSessionChanged: _refreshLaunchState,
        onSignedOut: _refreshLaunchState,
      );
    }

    return OnboardingScreen(
      key: const ValueKey('onboarding'),
      initialLearningGoal: _launchState?.learningGoal,
      startAtEntry: _launchState?.onboardingComplete ?? false,
      isSubmitting: _isSubmittingAuthRequest,
      errorMessage: _errorMessage,
      onStartGuestSession: _handleGuestSessionStart,
      onRegister: _handleRegister,
      onLogin: _handleLogin,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.learningGoalLabel,
    required this.sessionRepository,
    required this.onSessionChanged,
    required this.onSignedOut,
  });

  final String learningGoalLabel;
  final SessionRepository sessionRepository;
  final Future<void> Function() onSessionChanged;
  final Future<void> Function() onSignedOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _reviewRefreshSeed = 0;
  int _homeRefreshSeed = 0;
  int _insightRefreshSeed = 0;

  @override
  void initState() {
    super.initState();
    SyncManager.shared.start();
  }

  @override
  void dispose() {
    SyncManager.shared.stop();
    super.dispose();
  }

  List<Widget> get _screens => [
    HomeScreen(
      learningGoalLabel: widget.learningGoalLabel,
      onStartReview: () => _setTab(1, refreshReview: true),
      onAddMaterial: () => _setTab(2),
      refreshSeed: _homeRefreshSeed,
    ),
    ReviewScreen(
      refreshSeed: _reviewRefreshSeed,
      onCaptureRequested: () => _setTab(2),
    ),
    CaptureScreen(onCaptureSubmitted: () => _setTab(0, refreshReview: true)),
    InsightScreen(refreshSeed: _insightRefreshSeed),
    AccountScreen(
      sessionRepository: widget.sessionRepository,
      onSessionChanged: widget.onSessionChanged,
      onSignedOut: widget.onSignedOut,
    ),
  ];

  void _setTab(int index, {bool refreshReview = false}) {
    setState(() {
      _currentIndex = index;
      if (refreshReview || index == 1) {
        _reviewRefreshSeed += 1;
      }
      if (index == 0) {
        _homeRefreshSeed += 1;
      }
      if (index == 3) {
        _insightRefreshSeed += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SyncStatusBar(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => _setTab(index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.refresh_rounded),
                  label: 'Review',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_rounded),
                  label: 'Capture',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Insight',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusBar extends StatelessWidget {
  const _SyncStatusBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatusSnapshot>(
      valueListenable: SyncManager.shared.status,
      builder: (context, snapshot, child) {
        final color = switch (snapshot.phase) {
          SyncStatusPhase.syncing => AppColors.accent,
          SyncStatusPhase.error => AppColors.accentRed,
          SyncStatusPhase.pending => AppColors.accentOrange,
          SyncStatusPhase.synced => AppColors.accentGreen,
          SyncStatusPhase.idle => AppColors.textTertiary,
        };
        final icon = switch (snapshot.phase) {
          SyncStatusPhase.syncing => Icons.sync_rounded,
          SyncStatusPhase.error => Icons.error_outline_rounded,
          SyncStatusPhase.pending => Icons.cloud_off_rounded,
          SyncStatusPhase.synced => Icons.cloud_done_rounded,
          SyncStatusPhase.idle => Icons.cloud_queue_rounded,
        };
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  snapshot.label,
                  style: AppTypography.bodySmall.copyWith(color: color),
                ),
              ),
              if (snapshot.showRetry)
                TextButton(
                  onPressed:
                      () => SyncManager.shared.syncNow(reason: 'manual-retry'),
                  child: const Text('Retry'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
