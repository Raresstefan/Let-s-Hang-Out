import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';
import 'email_auth_screen.dart';

/// Full-screen branded sign-in shown when signed out. "Continue with Apple"
/// (iOS only, listed first per App Store 4.8), Google, and email drive
/// [AuthService]; the auth gate in [app.dart] swaps to the home shell.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Which provider's flow is running ('google' / 'apple'), or null if idle.
  String? _busyProvider;
  // i18n key of the error to show, or null.
  String? _errorKey;
  bool _showEmail = false;

  bool get _busy => _busyProvider != null;

  static bool get _showApple => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _signIn(String provider) async {
    final analytics = context.read<AnalyticsService>();
    final auth = context.read<AuthService>();
    analytics.buttonClicked('sign_in_$provider');
    setState(() {
      _busyProvider = provider;
      _errorKey = null;
    });
    try {
      if (provider == 'apple') {
        await auth.signInWithApple();
      } else {
        await auth.signInWithGoogle();
      }
      analytics.actionSuccess('signIn');
      // No navigation needed — the auth gate rebuilds on the auth state change.
    } on SignInCancelled {
      // User closed the sheet: nothing to report.
    } on AccountExistsWithOtherProvider catch (e) {
      if (mounted) {
        setState(() {
          _errorKey = e.existingProvider == 'google.com'
              ? 'auth.accountExistsUseGoogle'
              : 'auth.accountExistsOtherProvider';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'auth.error');
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showEmail) {
      return EmailAuthScreen(
        onBack: () => setState(() => _showEmail = false),
      );
    }
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
                if (_errorKey != null) ...[
                  Text(
                    l.tr(_errorKey!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showApple) ...[
                  _AppleButton(
                    busy: _busyProvider == 'apple',
                    label: _busyProvider == 'apple'
                        ? l.tr('auth.signingIn')
                        : l.tr('auth.continueWithApple'),
                    onTap: _busy ? null : () => _signIn('apple'),
                  ),
                  const SizedBox(height: 12),
                ],
                _GoogleButton(
                  busy: _busyProvider == 'google',
                  label: _busyProvider == 'google'
                      ? l.tr('auth.signingIn')
                      : l.tr('auth.continueWithGoogle'),
                  onTap: _busy ? null : () => _signIn('google'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _errorKey = null;
                          _showEmail = true;
                        }),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(l.tr('auth.continueWithEmail')),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF632F29),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF8A554C),
                    disabledForegroundColor: const Color(0xFFFFEAE5),
                    minimumSize: const Size.fromHeight(56),
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Black pill "Continue with Apple" button (Apple HIG black style), same size
/// as the Google button; shows a spinner while busy.
class _AppleButton extends StatelessWidget {
  const _AppleButton({
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
      color: Colors.black,
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.apple, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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
