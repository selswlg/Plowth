import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'auth_form_sheet.dart';
import 'session_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.sessionRepository,
    required this.onSessionChanged,
    required this.onSignedOut,
  });

  final SessionRepository sessionRepository;
  final Future<void> Function() onSessionChanged;
  final Future<void> Function() onSignedOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _goalOptions = <String>[
    'exam',
    'language',
    'professional',
    'self_improvement',
  ];

  AppUserProfile? _profile;
  bool _isLoading = true;
  bool _isSavingGoal = false;
  bool _isSigningOut = false;
  String? _errorMessage;
  String? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return _AccountErrorState(
        message: _errorMessage ?? 'Unable to load the current account.',
        onRetry: _loadProfile,
      );
    }

    final profile = _profile!;
    final goalValue = _selectedGoal ?? profile.learningGoal;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _AccountHeroCard(profile: profile, learningGoal: goalValue),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _AccountInlineBanner(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              title: 'Learning focus',
              subtitle:
                  'This updates local study defaults immediately and queues a sync event for the backend profile.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children:
                        _goalOptions.map((goal) {
                          final isSelected = goalValue == goal;
                          return ChoiceChip(
                            label: Text(
                              SessionRepository.describeLearningGoal(goal),
                            ),
                            selected: isSelected,
                            onSelected:
                                _isSavingGoal
                                    ? null
                                    : (selected) {
                                      if (selected) {
                                        _handleGoalChange(goal);
                                      }
                                    },
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                            ),
                            labelStyle: AppTypography.bodyMedium.copyWith(
                              color:
                                  isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.surfaceLight,
                          );
                        }).toList(),
                  ),
                  if (_isSavingGoal) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (profile.isGuest)
              _SectionCard(
                title: 'Upgrade this guest session',
                subtitle:
                    'Attach email login without resetting local progress or the current sync queue.',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleUpgradePressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Create Account From Guest Session'),
                  ),
                ),
              )
            else
              _SectionCard(
                title: 'Account status',
                subtitle: 'Email login is attached to this device session.',
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        profile.email ?? profile.displayName,
                        style: AppTypography.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              title: 'Session',
              subtitle:
                  'Logging out removes local tokens but keeps onboarding and goal selection on this device.',
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSigningOut ? null : _handleSignOut,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child:
                      _isSigningOut
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.accentRed,
                            ),
                          )
                          : const Text('Log Out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.sessionRepository.fetchCurrentUserProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _selectedGoal = profile.learningGoal;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoalChange(String learningGoal) async {
    setState(() {
      _isSavingGoal = true;
      _errorMessage = null;
      _selectedGoal = learningGoal;
    });

    try {
      await widget.sessionRepository.updateLearningGoal(learningGoal);
      await widget.onSessionChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${SessionRepository.describeLearningGoal(learningGoal)} saved. Sync will push the profile update next.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _selectedGoal = _profile?.learningGoal;
      });
    } finally {
      if (mounted) {
        setState(() => _isSavingGoal = false);
      }
    }
  }

  Future<void> _handleUpgradePressed() {
    return showAuthFormSheet(
      context: context,
      mode: AuthSheetMode.upgrade,
      onSubmit: (submission) async {
        await widget.sessionRepository.upgradeGuest(
          email: submission.email,
          password: submission.password,
          name: submission.name,
        );
        await widget.onSessionChanged();
        await _loadProfile();
      },
    );
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });

    try {
      await widget.sessionRepository.clearSession();
      await widget.onSignedOut();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }
}

class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard({required this.profile, required this.learningGoal});

  final AppUserProfile profile;
  final String? learningGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              profile.isGuest ? 'Guest Session' : 'Registered Account',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.displayName,
            style: AppTypography.displayMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            learningGoal == null
                ? 'Set a learning focus to keep sync and review defaults aligned on this device.'
                : 'Current focus: ${SessionRepository.describeLearningGoal(learningGoal)}',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  profile.email ?? 'No email attached yet',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _AccountInlineBanner extends StatelessWidget {
  const _AccountInlineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _AccountErrorState extends StatelessWidget {
  const _AccountErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search_rounded,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Account Unavailable', style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
