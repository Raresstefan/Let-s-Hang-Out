import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../domain/models/report.dart';
import 'safety_controller.dart';

/// Opens the report flow: pick a reason, optional details, submit.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  String? chatId,
  String? activityId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      target: target,
      targetId: targetId,
      chatId: chatId,
      activityId: activityId,
      messenger: ScaffoldMessenger.of(context),
    ),
  );
}

/// Confirms, then blocks [userId]. Returns true when the block went through.
Future<bool> confirmAndBlock(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final safety = context.read<SafetyController>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.tr('safety.blockConfirmTitle', {'name': name})),
      content: Text(l.tr('safety.blockConfirmBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.tr('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.tr('safety.block')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await safety.block(userId);
    messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.blocked', {'name': name}))));
    return true;
  } catch (_) {
    messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.actionFailed'))));
    return false;
  }
}

Future<void> unblockUser(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<SafetyController>().unblock(userId);
    messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.unblocked', {'name': name}))));
  } catch (_) {
    messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.actionFailed'))));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.target,
    required this.targetId,
    required this.messenger,
    this.chatId,
    this.activityId,
  });

  final ReportTarget target;
  final String targetId;
  final String? chatId;
  final String? activityId;
  final ScaffoldMessengerState messenger;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await context.read<SafetyController>().report(
            target: widget.target,
            targetId: widget.targetId,
            reason: reason,
            details: _details.text,
            chatId: widget.chatId,
            activityId: widget.activityId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(
          SnackBar(content: Text(l.tr('safety.reportSent'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      widget.messenger.showSnackBar(
          SnackBar(content: Text(l.tr('safety.reportFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.tr('safety.reportTitle'),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.tr('safety.reportSubtitle'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.tr('safety.reasons.${r.id}')),
                    ),
                ],
              ),
            ),
            if (_reason == ReportReason.safety)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.tr('safety.emergency'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            TextField(
              controller: _details,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l.tr('safety.detailsHint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null || _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.tr('safety.submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
