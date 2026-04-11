import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../auth/auth_form_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onStartGuestSession,
    required this.onRegister,
    required this.onLogin,
    this.initialLearningGoal,
    this.errorMessage,
    this.isSubmitting = false,
    this.startAtEntry = false,
  });

  final Future<void> Function(String learningGoal) onStartGuestSession;
  final Future<void> Function({
    required String learningGoal,
    required String email,
    required String password,
    String? name,
  })
  onRegister;
  final Future<void> Function({required String email, required String password})
  onLogin;
  final String? initialLearningGoal;
  final String? errorMessage;
  final bool isSubmitting;
  final bool startAtEntry;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingStage { intro, goal, entry }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  String? _selectedGoal;
  _OnboardingStage _stage = _OnboardingStage.intro;

  final List<_ValueSlide> _slides = const [
    _ValueSlide(
      icon: Icons.auto_awesome_rounded,
      title: 'Turn raw material into cards in minutes.',
      subtitle:
          'Paste text or upload learning material and let Plowth draft your first review set.',
    ),
    _ValueSlide(
      icon: Icons.timeline_rounded,
      title: 'Review on the right day, not every day.',
      subtitle:
          'The review engine schedules cards around memory decay so your time stays focused.',
    ),
    _ValueSlide(
      icon: Icons.psychology_rounded,
      title: 'See where recall actually breaks.',
      subtitle:
          'Plowth is designed to connect capture, review, and insight into one learning loop.',
    ),
  ];

  final List<_GoalOption> _goals = const [
    _GoalOption(
      icon: Icons.school_rounded,
      label: 'Exam Prep',
      description: 'For certifications, coursework, and dense study plans.',
      value: 'exam',
    ),
    _GoalOption(
      icon: Icons.translate_rounded,
      label: 'Language Learning',
      description: 'For vocab, phrases, and recurring exposure.',
      value: 'language',
    ),
    _GoalOption(
      icon: Icons.code_rounded,
      label: 'Professional Growth',
      description: 'For technical concepts, frameworks, and domain knowledge.',
      value: 'professional',
    ),
    _GoalOption(
      icon: Icons.emoji_objects_rounded,
      label: 'Self Improvement',
      description: 'For personal systems, ideas, and practical habits.',
      value: 'self_improvement',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.initialLearningGoal;
    _stage =
        widget.startAtEntry
            ? (widget.initialLearningGoal == null
                ? _OnboardingStage.goal
                : _OnboardingStage.entry)
            : _OnboardingStage.intro;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_stage) {
            _OnboardingStage.intro => _buildIntroStage(),
            _OnboardingStage.goal => _buildGoalStage(),
            _OnboardingStage.entry => _buildEntryStage(),
          },
        ),
      ),
    );
  }

  Widget _buildIntroStage() {
    return Column(
      key: const ValueKey('intro-stage'),
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: _showGoalStage,
            child: Text('Skip', style: AppTypography.bodyMedium),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (_, index) => _buildSlide(_slides[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleIntroAdvance,
              child: Text(
                _currentPage == _slides.length - 1 ? 'Choose Goal' : 'Next',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalStage() {
    return Padding(
      key: const ValueKey('goal-stage'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButtonRow(
            title: 'What are you optimizing for?',
            onBack: () => setState(() => _stage = _OnboardingStage.intro),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This helps us shape the first capture and review flow.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView.separated(
              itemCount: _goals.length,
              separatorBuilder:
                  (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, index) {
                final goal = _goals[index];
                final isSelected = _selectedGoal == goal.value;
                return _GoalCard(
                  goal: goal,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedGoal = goal.value),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  _selectedGoal == null
                      ? null
                      : () => setState(() => _stage = _OnboardingStage.entry),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryStage() {
    final selectedGoal = _selectedGoal;
    final goalLabel =
        _goals.firstWhere((goal) => goal.value == selectedGoal).label;

    return Padding(
      key: const ValueKey('entry-stage'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButtonRow(
            title: 'Start with a guest session',
            onBack: () => setState(() => _stage = _OnboardingStage.goal),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Goal: $goalLabel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Start in guest mode for the fastest path, or attach email login now. All three flows land in the same local session storage and sync queue.',
            style: AppTypography.bodyMedium,
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorBanner(message: widget.errorMessage!),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  widget.isSubmitting || selectedGoal == null
                      ? null
                      : () => widget.onStartGuestSession(selectedGoal),
              child:
                  widget.isSubmitting
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                      : const Text('Continue as Guest'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: widget.isSubmitting ? null : _openRegisterSheet,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('Register With Email'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: widget.isSubmitting ? null : _openLoginSheet,
              child: Text(
                'Already have an account? Log in',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_ValueSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.glow,
            ),
            child: Icon(slide.icon, size: 56, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            style: AppTypography.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.subtitle,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleIntroAdvance() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      return;
    }

    _showGoalStage();
  }

  void _showGoalStage() {
    setState(() => _stage = _OnboardingStage.goal);
  }

  Future<void> _openRegisterSheet() {
    final selectedGoal = _selectedGoal;
    if (selectedGoal == null) {
      setState(() => _stage = _OnboardingStage.goal);
      return Future.value();
    }

    return showAuthFormSheet(
      context: context,
      mode: AuthSheetMode.register,
      onSubmit: (submission) {
        return widget.onRegister(
          learningGoal: selectedGoal,
          email: submission.email,
          password: submission.password,
          name: submission.name,
        );
      },
    );
  }

  Future<void> _openLoginSheet() {
    return showAuthFormSheet(
      context: context,
      mode: AuthSheetMode.login,
      onSubmit: (submission) {
        return widget.onLogin(
          email: submission.email,
          password: submission.password,
        );
      },
    );
  }
}

class _ValueSlide {
  const _ValueSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _GoalOption {
  const _GoalOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String description;
  final String value;
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final _GoalOption goal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                goal.icon,
                color:
                    isSelected
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.label, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(goal.description, style: AppTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _BackButtonRow extends StatelessWidget {
  const _BackButtonRow({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(child: Text(title, style: AppTypography.displayMedium)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
