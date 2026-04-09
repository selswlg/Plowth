import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'features/auth/session_repository.dart';
import 'features/capture_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/review_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealApp());
}

class RealApp extends StatefulWidget {
  const RealApp({super.key});

  @override
  State<RealApp> createState() => _RealAppState();
}

class _RealAppState extends State<RealApp> {
  late final SessionRepository _sessionRepository;

  AppLaunchState? _launchState;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCreatingGuestSession = false;

  @override
  void initState() {
    super.initState();
    _sessionRepository = SessionRepository();
    _loadLaunchState();
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
    setState(() {
      _isCreatingGuestSession = true;
      _errorMessage = null;
    });

    try {
      await _sessionRepository.createGuestSession(learningGoal: learningGoal);
      final launchState = await _sessionRepository.loadLaunchState();
      if (!mounted) {
        return;
      }

      setState(() {
        _launchState = launchState;
      });
    } on SessionException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Guest session setup failed unexpectedly.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGuestSession = false;
        });
      }
    }
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
      );
    }

    return OnboardingScreen(
      key: const ValueKey('onboarding'),
      initialLearningGoal: _launchState?.learningGoal,
      isSubmitting: _isCreatingGuestSession,
      errorMessage: _errorMessage,
      onStartGuestSession: _handleGuestSessionStart,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.learningGoalLabel});

  final String learningGoalLabel;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _reviewRefreshSeed = 0;
  int _homeRefreshSeed = 0;

  List<Widget> get _screens => [
    HomeScreen(
      learningGoalLabel: widget.learningGoalLabel,
      onStartReview: () => _setTab(1),
      onAddMaterial: () => _setTab(2),
      refreshSeed: _homeRefreshSeed,
    ),
    ReviewScreen(
      refreshSeed: _reviewRefreshSeed,
      onCaptureRequested: () => _setTab(2),
    ),
    CaptureScreen(onStartReview: () => _setTab(1, refreshReview: true)),
    const _PlaceholderScreen(
      title: 'Insight',
      description: 'Analytics and coaching arrive after the core loop.',
      icon: Icons.insights_rounded,
    ),
    const _PlaceholderScreen(
      title: 'Profile',
      description: 'Account upgrade and preferences are still pending.',
      icon: Icons.person_outline_rounded,
    ),
  ];

  void _setTab(int index, {bool refreshReview = false}) {
    setState(() {
      _currentIndex = index;
      if (refreshReview) {
        _reviewRefreshSeed += 1;
      }
      if (index == 0) {
        _homeRefreshSeed += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
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
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
