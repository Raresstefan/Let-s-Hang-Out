import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';

/// Full-screen branded sign-in shown when signed out. A single "Continue with
/// Google" button drives [AuthService.signInWithGoogle]; the auth gate in
/// [app.dart] swaps to the home shell once signed in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _signIn() async {
    final analytics = context.read<AnalyticsService>();
    final auth = context.read<AuthService>();
    analytics.buttonClicked('sign_in_google');
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await auth.signInWithGoogle();
      analytics.actionSuccess('signIn');
      // No navigation needed — the auth gate rebuilds on the auth state change.
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 3),
                Text(
                  l.tr('app.name'),
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: Colors.white, fontSize: 44),
                ),
                const SizedBox(height: 12),
                Text(
                  l.tr('auth.tagline'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const Spacer(flex: 4),
                if (_failed) ...[
                  Text(
                    l.tr('auth.error'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                ],
                _GoogleButton(
                  busy: _busy,
                  label: _busy
                      ? l.tr('auth.signingIn')
                      : l.tr('auth.continueWithGoogle'),
                  onTap: _busy ? null : _signIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill button with the Google "G" mark; shows a spinner while busy.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                const _GoogleG(),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small multi-color "G" stand-in (avoids bundling an asset for this pass).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
