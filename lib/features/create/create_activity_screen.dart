import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/mock_activity_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import '../feed/feed_controller.dart';

/// Host-facing form to create a new activity. Title, description, place and
/// start date are all required (entered by the host, per the spec).
class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _coverUrl = TextEditingController();

  DateTime? _startAt;
  ActivityCategory _category = ActivityCategory.drinks;
  bool _submitting = false;

  late final AnalyticsService _analytics = context.read<AnalyticsService>();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    _coverUrl.dispose();
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
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    _analytics.buttonClicked('create_activity_submit');
    if (!_formKey.currentState!.validate() || _startAt == null) {
      if (_startAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tr('activity.label.startDate'))),
        );
      }
      return;
    }
    setState(() => _submitting = true);

    final draft = Activity(
      id: '',
      title: _title.text.trim(),
      description: _description.text.trim(),
      placeSuggestion: _place.text.trim(),
      startAt: _startAt!,
      hostId: MockActivityRepository.currentUserId,
      category: _category,
      coverImageUrl: _coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim(),
    );

    final controller = context.read<FeedController>();
    await context.read<ActivityCreator>().create(draft);
    await controller.load();
    _analytics.actionSuccess('createActivity');

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).maybePop();
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(
              controller: _title,
              label: l.tr('activity.label.title'),
              hint: l.tr('activity.placeholder.title'),
              inputName: 'activity_title',
            ),
            const SizedBox(height: 16),
            _field(
              controller: _description,
              label: l.tr('activity.label.description'),
              hint: l.tr('activity.placeholder.description'),
              inputName: 'activity_description',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _place,
              label: l.tr('activity.label.place'),
              hint: l.tr('activity.placeholder.place'),
              inputName: 'activity_place',
            ),
            const SizedBox(height: 16),
            _field(
              controller: _coverUrl,
              label: l.tr('activity.label.coverImage'),
              hint: l.tr('activity.create.coverHint'),
              inputName: 'activity_cover',
              required: false,
            ),
            const SizedBox(height: 16),
            Text(l.tr('activity.label.startDate'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickStart,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(dateLabel),
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
    int maxLines = 1,
    bool required = true,
  }) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          // Fires `Hang:${input_name}:Typing` once per field.
          onChanged: (_) => _analytics.inputTyping(inputName),
          decoration: InputDecoration(hintText: hint),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? l.tr('common.error.generic')
                  : null
              : null,
        ),
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
