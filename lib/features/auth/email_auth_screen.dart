import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/auth/auth_service.dart';
import 'auth_page.dart';
import 'email_auth_errors.dart';

enum _EmailMode { signIn, signUp, reset }

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _EmailMode _mode = _EmailMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _errorKey;
  String? _messageKey;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(_EmailMode mode) {
    setState(() {
      _mode = mode;
      _errorKey = null;
      _messageKey = null;
      _password.clear();
      _obscurePassword = true;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final analytics = context.read<AnalyticsService>();
    final mode = _mode;
    analytics.buttonClicked(switch (mode) {
      _EmailMode.signIn => 'sign_in_email',
      _EmailMode.signUp => 'sign_up_email',
      _EmailMode.reset => 'reset_password',
    });
    setState(() {
      _busy = true;
      _errorKey = null;
      _messageKey = null;
    });
    try {
      switch (mode) {
        case _EmailMode.signIn:
          await auth.signInWithEmail(
            email: _email.text,
            password: _password.text,
          );
          analytics.actionSuccess('signIn');
        case _EmailMode.signUp:
          await auth.signUpWithEmail(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
          analytics.actionSuccess('signUp');
        case _EmailMode.reset:
          await auth.sendPasswordResetEmail(_email.text);
          if (mounted) {
            setState(() {
              _messageKey = auth.emailActionsAreSimulated
                  ? 'auth.email.resetSentMock'
                  : 'auth.email.resetSent';
            });
          }
      }
    } on EmailAuthException catch (e) {
      if (mounted) setState(() => _errorKey = emailAuthErrorKey(e.reason));
    } catch (e) {
      debugPrint('Email authentication failed: ${e.runtimeType}');
      if (mounted) setState(() => _errorKey = 'auth.email.errors.unknown');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isSignUp = _mode == _EmailMode.signUp;
    final isReset = _mode == _EmailMode.reset;
    final titleKey = switch (_mode) {
      _EmailMode.signIn => 'auth.email.signInTitle',
      _EmailMode.signUp => 'auth.email.signUpTitle',
      _EmailMode.reset => 'auth.email.resetTitle',
    };
    final buttonKey = switch (_mode) {
      _EmailMode.signIn => 'auth.email.signInAction',
      _EmailMode.signUp => 'auth.email.signUpAction',
      _EmailMode.reset => 'auth.email.resetAction',
    };

    return AuthPage(
      onBack: _busy
          ? null
          : isReset
          ? () => _switchMode(_EmailMode.signIn)
          : widget.onBack,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.tr(titleKey), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l.tr(
                  isReset
                      ? 'auth.email.resetSubtitle'
                      : isSignUp
                      ? 'auth.email.signUpSubtitle'
                      : 'auth.email.subtitle',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (isSignUp) ...[
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: l.tr('auth.email.name'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.tr('auth.email.nameRequired')
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                enabled: !_busy,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                keyboardType: TextInputType.emailAddress,
                textInputAction: isReset
                    ? TextInputAction.done
                    : TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l.tr('auth.email.address'),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty ||
                      !email.contains('@') ||
                      email.contains(' ')) {
                    return l.tr('auth.email.errors.invalidEmail');
                  }
                  return null;
                },
                onFieldSubmitted: isReset ? (_) => _submit() : null,
              ),
              if (!isReset) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    isSignUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: l.tr('auth.email.password'),
                    suffixIcon: IconButton(
                      tooltip: l.tr(
                        _obscurePassword
                            ? 'auth.email.showPassword'
                            : 'auth.email.hidePassword',
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l.tr('auth.email.passwordRequired');
                    }
                    if (isSignUp && value.length < 6) {
                      return l.tr('auth.email.passwordTooShort');
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              if (_errorKey != null || _messageKey != null) ...[
                const SizedBox(height: 16),
                Text(
                  l.tr(_errorKey ?? _messageKey!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _errorKey != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.tr(buttonKey)),
                ),
              ),
              if (!isReset) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _switchMode(
                          isSignUp ? _EmailMode.signIn : _EmailMode.signUp,
                        ),
                  child: Text(
                    l.tr(
                      isSignUp
                          ? 'auth.email.haveAccount'
                          : 'auth.email.needAccount',
                    ),
                  ),
                ),
                if (!isSignUp)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _switchMode(_EmailMode.reset),
                    child: Text(l.tr('auth.email.forgotPassword')),
                  ),
              ] else ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _switchMode(_EmailMode.signIn),
                  child: Text(l.tr('auth.email.backToSignIn')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
