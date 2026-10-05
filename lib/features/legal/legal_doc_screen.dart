import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';

/// Shows a bundled legal markdown doc (`docs/*.md`) in-app, so the Terms and
/// Privacy Policy are always reachable — even offline or before the docs are
/// hosted. Renders the small markdown subset those docs use: headings,
/// bullets, blockquotes, tables (as plain rows) and **bold**.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.title, required this.asset});

  final String title;
  final String asset;

  static Future<void> open(BuildContext context, String title, String asset) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LegalDocScreen(title: title, asset: asset),
      ));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l.tr('common.error.generic')));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocks = _parse(snap.data!);
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [for (final b in blocks) _render(context, b)],
            ),
          );
        },
      ),
    );
  }

  static List<(String, String)> _parse(String md) {
    var lines = md.split('\n');
    // Drop the Jekyll front matter (--- … ---).
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      final end = lines.indexWhere((x) => x.trim() == '---', 1);
      if (end != -1) lines = lines.sublist(end + 1);
    }
    final out = <(String, String)>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.startsWith('# ')) {
        out.add(('h1', line.substring(2)));
      } else if (line.startsWith('## ')) {
        out.add(('h2', line.substring(3)));
      } else if (line.startsWith('### ')) {
        out.add(('h3', line.substring(4)));
      } else if (line.trimLeft().startsWith('- ')) {
        out.add(('li', line.trimLeft().substring(2)));
      } else if (line.startsWith('> ')) {
        out.add(('quote', line.substring(2)));
      } else if (line.startsWith('|')) {
        if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(line)) continue;
        final cells = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .join('  ·  ');
        out.add(('row', cells));
      } else {
        out.add(('p', line));
      }
    }
    return out;
  }

  /// Inline **bold** + [link](url) → text spans.
  static List<TextSpan> _inline(String text, TextStyle? base) {
    final link = RegExp(r'\[([^\]]+)\]\([^)]+\)');
    text = text.replaceAllMapped(link, (m) => m[1]!);
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? base?.copyWith(fontWeight: FontWeight.w700) : base,
      ));
    }
    return spans;
  }

  Widget _render(BuildContext context, (String, String) b) {
    final t = Theme.of(context).textTheme;
    final (kind, text) = b;
    switch (kind) {
      case 'h1':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text, style: t.headlineSmall),
        );
      case 'h2':
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(text, style: kind == 'h2' ? t.titleMedium : t.titleSmall),
        );
      case 'li':
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: t.bodyMedium),
              Expanded(
                child: Text.rich(TextSpan(children: _inline(text, t.bodyMedium))),
              ),
            ],
          ),
        );
      case 'quote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(TextSpan(children: _inline(text, t.bodyMedium))),
        );
      case 'row':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(TextSpan(children: _inline(text, t.bodySmall))),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(children: _inline(text, t.bodyMedium?.copyWith(height: 1.45))),
          ),
        );
    }
  }
}
