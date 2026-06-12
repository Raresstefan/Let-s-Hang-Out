import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import '../feed/feed_controller.dart';
import 'widgets/cover_drop_zone.dart';

/// Host-facing form to create a new activity. Title, description, place and
/// start date are all required (entered by the host, per the spec).
class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({
    super.key,
    this.circleId,
    this.prefillMemberIds = const [],
    this.prefillTitle,
    this.prefillPlace,
    this.prefillCategory,
  });

  /// When set, the created activity is linked to this circle and seeded with
  /// [prefillMemberIds] (the circle's members) — the "Plan a hangout" flow.
  final String? circleId;
  final List<String> prefillMemberIds;

  /// Optional prefills for the "Hang again" flow (reuse a past activity's
  /// title / place / category). The start time is always re-picked.
  final String? prefillTitle;
  final String? prefillPlace;
  final ActivityCategory? prefillCategory;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();

  /// Cover image as a data URL produced by the drop zone (null = none).
  String? _coverDataUrl;

  DateTime? _startAt;
  String? _startError; // inline validation message for the date picker
  ActivityCategory _category = ActivityCategory.drinks;
  bool _submitting = false;
  bool _autovalidate = false; // turns on after the first submit attempt

  late final AnalyticsService _analytics = context.read<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    // Seed from prefills (e.g. "Hang again" reusing a past activity).
    if (widget.prefillTitle != null) _title.text = widget.prefillTitle!;
    if (widget.prefillPlace != null) _place.text = widget.prefillPlace!;
    if (widget.prefillCategory != null) _category = widget.prefillCategory!;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    _analytics.buttonClicked('create_pick_start_date');
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    setState(() {
      _startAt = DateTime(date.year, date.month, date.day,
          time?.hour ?? 12, time?.minute ?? 0);
      _startError = null; // clear any prior error once a date is chosen
    });
  }

  /// Validates the start date and stores an inline message if invalid.
  /// Returns true when the date is valid.
  bool _validateStart(AppLocalizations l) {
    String? error;
    if (_startAt == null) {
      error = l.tr('activity.validation.startRequired');
    } else if (_startAt!.isBefore(DateTime.now())) {
      error = l.tr('activity.validation.startInPast');
    }
    setState(() => _startError = error);
    return error == null;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    _analytics.buttonClicked('create_activity_submit');
    setState(() => _autovalidate = true);
    // Validate all fields; combine so every problem shows at once.
    final fieldsValid = _formKey.currentState!.validate();
    final startValid = _validateStart(l);
    if (!fieldsValid || !startValid) return;

    setState(() => _submitting = true);

    final draft = Activity(
      id: '',
      title: _title.text.trim(),
      description: _description.text.trim(),
      placeSuggestion: _place.text.trim(),
      startAt: _startAt!,
      hostId: context.read<AuthService>().currentUserId!,
      category: _category,
      coverImageUrl: _coverDataUrl,
      // Circle hangout: link + seed members (the repo adds the host + dedupes).
      circleId: widget.circleId,
      memberIds: widget.prefillMemberIds,
    );

    final controller = context.read<FeedController>();
    final auth = context.read<AuthService>();
    final chats = context.read<ChatRepository>();
    final uid = auth.currentUserId;
    await context.read<ActivityCreator>().create(draft);
    await controller.load();
    _analytics.actionSuccess('createActivity');

    // Circle hangout: announce it in the circle's persistent chat so members
    // see it (the chat lives at chats/{circleId}). Best-effort.
    if (widget.circleId != null && uid != null) {
      final planner = (auth.displayName?.trim().isNotEmpty ?? false)
          ? auth.displayName!
          : 'Someone';
      try {
        await chats.sendSystemMessage(
          widget.circleId!,
          actorId: uid,
          text: l.tr('chat.systemPlanned',
              {'name': planner, 'title': draft.title}),
        );
      } catch (_) {/* the hangout still exists; ignore */}
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    // Pop with `true` so the home shell knows an activity was created and can
    // refresh the My Activities tab (otherwise it stays stale on return).
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dateLabel = _startAt == null
        ? l.tr('activity.placeholder.startDate')
        : _startAt!.toLocal().toString().substring(0, 16);

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('activity.create.title'))),
      body: Form(
        key: _formKey,
        // After the first submit attempt, re-validate fields as the user edits
        // so the helpful messages clear the moment each field is fixed.
        autovalidateMode: _autovalidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(
              controller: _title,
              label: l.tr('activity.label.title'),
              hint: l.tr('activity.placeholder.title'),
              inputName: 'activity_title',
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? l.tr('activity.validation.titleRequired')
                  : null,
            ),
            const SizedBox(height: 16),
            // Description is optional — a missing description is a valid case.
            _field(
              controller: _description,
              label: l.tr('activity.label.description'),
              hint: l.tr('activity.placeholder.description'),
              inputName: 'activity_description',
              maxLines: 3,
              optional: true,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _place,
              label: l.tr('activity.label.place'),
              hint: l.tr('activity.placeholder.place'),
              inputName: 'activity_place',
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? l.tr('activity.validation.placeRequired')
                  : null,
            ),
            const SizedBox(height: 16),
            // Cover image is optional too — no error when missing.
            _LabelRow(
              label: l.tr('activity.label.coverImage'),
              optionalText: l.tr('activity.label.optional'),
            ),
            const SizedBox(height: 6),
            CoverDropZone(
              hint: l.tr('activity.create.coverHint'),
              onChanged: (dataUrl) {
                // Fire the typing/interaction event once, like other inputs.
                if (dataUrl != null) _analytics.inputTyping('activity_cover');
                setState(() => _coverDataUrl = dataUrl);
              },
            ),
            const SizedBox(height: 16),
            Text(l.tr('activity.label.startDate'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickStart,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(dateLabel),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: _startError != null
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.error, width: 1.5)
                    : null,
              ),
            ),
            if (_startError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  _startError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ActivityCategory.values.map((c) {
                return ChoiceChip(
                  label: Text('${c.emoji} ${c.id}'),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.tr('activity.create.submit')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String inputName,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool optional = false,
  }) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelRow(
          label: label,
          optionalText: optional ? l.tr('activity.label.optional') : null,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          // Fires `Hang:${input_name}:Typing` once per field.
          onChanged: (_) => _analytics.inputTyping(inputName),
          decoration: InputDecoration(hintText: hint),
          validator: validator,
        ),
      ],
    );
  }
}

/// A field label with an optional "optional" pill next to it.
class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, this.optionalText});

  final String label;
  final String? optionalText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (optionalText != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              optionalText!,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Thin wrapper around the repository's create call, provided via Provider so
/// the screen doesn't reach into the repository directly.
class ActivityCreator {
  ActivityCreator(this._repository);
  final ActivityRepository _repository;
  Future<void> create(Activity draft) => _repository.createActivity(draft);
}
