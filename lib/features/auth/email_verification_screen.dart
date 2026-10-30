import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../data/auth/auth_service.dart';
import 'auth_page.dart';
import 'email_auth_errors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  String? _feedbackKey;
  bool _feedbackIsError = false;

  Future<void> _perform(
    Future<String?> Function(AuthService auth) action,
  ) async {
    if (_busy) return;
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _feedbackKey = null;
    });
    try {
      final message = await action(auth);
      if (mounted && message != null) {
        setState(() {
          _feedbackKey = message;
          _feedbackIsError = false;
        });
      }
    } on EmailAuthException catch (e) {
      if (mounted) {
        setState(() {
          _feedbackKey = emailAuthErrorKey(e.reason);
          _feedbackIsError = true;
        });
      }
    } catch (e) {
      debugPrint('Email verification action failed: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _feedbackKey = 'auth.email.errors.unknown';
          _feedbackIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final instructionsKey = auth.emailActionsAreSimulated
        ? 'auth.email.verifyMock'
        : auth.verificationEmailStatus == VerificationEmailStatus.failed
        ? 'auth.email.verifySendFailed'
        : 'auth.email.verifyInstructions';

    return AuthPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 44,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l.tr('auth.email.verifyTitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            l.tr(instructionsKey, {'email': auth.emailAddress}),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (auth.emailDisplayNameSaveFailed) ...[
            const SizedBox(height: 16),
            Text(
              l.tr('auth.email.nameSaveFailed'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (auth.emailVerificationRefreshFailed && _feedbackKey == null) ...[
            const SizedBox(height: 16),
            Text(
              l.tr('auth.email.verifyRefreshFailed'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_feedbackKey != null) ...[
            const SizedBox(height: 16),
            Text(
              l.tr(_feedbackKey!),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _feedbackIsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _perform((auth) async {
                      final verified = await auth.refreshEmailVerification();
                      return verified ? null : 'auth.email.verifyNotYet';
                    }),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.tr('auth.email.verifyCheck')),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => _perform((auth) async {
                    await auth.sendEmailVerification();
                    return auth.emailActionsAreSimulated
                        ? 'auth.email.verifyResentMock'
                        : 'auth.email.verifyResent';
                  }),
            child: Text(l.tr('auth.email.verifyResend')),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _perform((auth) async {
                    await auth.signOut();
                    return null;
                  }),
            child: Text(l.tr('auth.email.signOut')),
          ),
          const SizedBox(height: 12),
          Text(
            l.tr('auth.email.verifyDeletionHelp'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
