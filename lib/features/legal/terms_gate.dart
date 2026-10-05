import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/legal/legal.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/user_repository.dart';
import 'legal_doc_screen.dart';

/// Shows [child] only once the signed-in user has accepted the current
/// community rules / Terms ([kTermsVersion]). Required by App Store 1.2 and
/// Play's UGC policy (users must agree to zero-tolerance terms before posting).
class TermsGate extends StatefulWidget {
  const TermsGate({super.key, required this.child});

  final Widget child;

  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  String? _uid;
  bool? _accepted;

  Future<void> _load(String uid) async {
    setState(() => _accepted = null);
    var accepted = false;
    try {
      final v =
          await context.read<UserRepository>().acceptedTermsVersion(uid);
      accepted = v >= kTermsVersion;
    } catch (_) {
      // Unknown (offline / read error): ask again rather than skip the gate.
    }
    if (mounted && _uid == uid) setState(() => _accepted = accepted);
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUserId;
    if (uid != _uid) {
      _uid = uid;
      if (uid != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _load(uid));
      }
      _accepted = null;
    }
    if (uid == null) return widget.child;
    if (_accepted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accepted!) return widget.child;
    return _TermsScreen(
      uid: uid,
      onAccepted: () => setState(() => _accepted = true),
    );
  }
}

class _TermsScreen extends StatefulWidget {
  const _TermsScreen({required this.uid, required this.onAccepted});

  final String uid;
  final VoidCallback onAccepted;

  @override
  State<_TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<_TermsScreen> {
  bool _checked = false;
  bool _saving = false;

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final analytics = context.read<AnalyticsService>();
    setState(() => _saving = true);
    try {
      await context
          .read<UserRepository>()
          .acceptTerms(widget.uid, kTermsVersion);
      analytics.actionSuccess('acceptTerms',
          params: {'version': kTermsVersion});
      widget.onAccepted();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
          SnackBar(content: Text(l.tr('legal.saveFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rules = ['respect', 'content', 'honest', 'safety'];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(l.tr('legal.rulesTitle'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l.tr('legal.rulesIntro'),
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l.tr('legal.rules.$r'),
                          style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.seed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(l.tr('legal.enforcement'),
                  style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => LegalDocScreen.open(
                      context, l.tr('legal.terms'), kTermsAsset),
                  child: Text(l.tr('legal.readTerms')),
                ),
                TextButton(
                  onPressed: () => LegalDocScreen.open(
                      context, l.tr('legal.privacy'), kPrivacyAsset),
                  child: Text(l.tr('legal.readPrivacy')),
                ),
              ],
            ),
            CheckboxListTile(
              value: _checked,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _saving ? null : (v) => setState(() => _checked = v!),
              title: Text(l.tr('legal.agreeCheckbox')),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _checked && !_saving ? _accept : null,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.tr('legal.agree')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _saving ? null : () => context.read<AuthService>().signOut(),
              child: Text(l.tr('legal.decline')),
            ),
          ],
        ),
      ),
    );
  }
}
