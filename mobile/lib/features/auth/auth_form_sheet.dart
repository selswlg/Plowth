import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum AuthSheetMode { register, login, upgrade }

class AuthSheetSubmission {
  const AuthSheetSubmission({
    required this.email,
    required this.password,
    this.name,
  });

  final String email;
  final String password;
  final String? name;
}

Future<void> showAuthFormSheet({
  required BuildContext context,
  required AuthSheetMode mode,
  required Future<void> Function(AuthSheetSubmission submission) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthFormSheet(mode: mode, onSubmit: onSubmit),
  );
}

class _AuthFormSheet extends StatefulWidget {
  const _AuthFormSheet({required this.mode, required this.onSubmit});

  final AuthSheetMode mode;
  final Future<void> Function(AuthSheetSubmission submission) onSubmit;

  @override
  State<_AuthFormSheet> createState() => _AuthFormSheetState();
}

class _AuthFormSheetState extends State<_AuthFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _showsNameField => switch (widget.mode) {
    AuthSheetMode.register || AuthSheetMode.upgrade => true,
    AuthSheetMode.login => false,
  };

  String get _title => switch (widget.mode) {
    AuthSheetMode.register => 'Create your account',
    AuthSheetMode.login => 'Sign back in',
    AuthSheetMode.upgrade => 'Upgrade guest session',
  };

  String get _subtitle => switch (widget.mode) {
    AuthSheetMode.register =>
      'Use email login now, keep the same local review loop, and sync the rest later.',
    AuthSheetMode.login =>
      'Restore your account on this device and continue from the same queue.',
    AuthSheetMode.upgrade =>
      'Attach email login to this guest session without resetting local study progress.',
  };

  String get _submitLabel => switch (widget.mode) {
    AuthSheetMode.register => 'Create Account',
    AuthSheetMode.login => 'Log In',
    AuthSheetMode.upgrade => 'Upgrade Account',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          bottomInset + AppSpacing.md,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.medium,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_title, style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_subtitle, style: AppTypography.bodyMedium),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _InlineError(message: _errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_showsNameField) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Email is required.';
                      }
                      if (!trimmed.contains('@') || !trimmed.contains('.')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: switch (widget.mode) {
                      AuthSheetMode.login => const [AutofillHints.password],
                      AuthSheetMode.register || AuthSheetMode.upgrade => const [
                        AutofillHints.newPassword,
                      ],
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText:
                          widget.mode == AuthSheetMode.login
                              ? 'Enter your password'
                              : 'At least 8 characters',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Password is required.';
                      }
                      if (widget.mode != AuthSheetMode.login &&
                          trimmed.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                              : Text(_submitLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        AuthSheetSubmission(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name:
              _nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
