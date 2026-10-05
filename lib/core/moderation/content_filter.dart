/// Lightweight client-side filter for objectionable language (App Store 1.2 /
/// Play UGC "filtering" requirement). Word-based to avoid false positives
/// inside innocent words (e.g. "class", "cocktail"); handles case, common
/// leetspeak, Romanian diacritics and stretched letters ("fuuuck").
///
/// Chat messages are masked ([mask]); titles, bios, etc. are rejected
/// ([hasBlocked]). Reports + moderation cover what this misses.
class ContentFilter {
  ContentFilter._();

  /// Blocked when a word *starts with* one of these (fucking, shithead…).
  static const _roots = <String>{
    'fuck', 'fck', 'fuk', 'phuck', 'motherfuck', 'shit', 'bullshit', 'cunt', 'bitch', 'whore',
    'slut', 'nigger', 'nigga', 'faggot', 'retard', 'asshole', 'dickhead',
    'wanker', 'twat', 'bastard', 'porn', 'pedophil', 'paedophil', 'rapist',
    'kike', 'tranny',
    // Romanian
    'pizd', 'futut', 'muist', 'poponar', 'cacat', 'labagi',
  };

  /// Blocked only as whole words (they're prefixes of innocent words).
  static const _words = <String>{
    'ass', 'dick', 'cock', 'pussy', 'fag', 'fags', 'spic', 'chink', 'kys',
    'jizz', 'tits', 'dildo', 'milf',
    // Romanian
    'pula', 'pule', 'muie', 'fut', 'futu', 'fute', 'futi', 'coaie', 'curva',
    'curvo', 'tigan', 'tigani', 'bozgor',
  };

  static const _phrases = <String>['kill yourself', 'kill urself', 'go die'];

  static const _leet = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a',
    r'$': 's', 'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't',
    'ţ': 't',
  };

  static final _token = RegExp(r'[\p{L}\p{N}@$]+', unicode: true);
  static final _runs = RegExp(r'(.)\1{2,}');

  static String _normalize(String token) {
    final lower = token.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      b.write(_leet[ch] ?? ch);
    }
    return b.toString();
  }

  static String _collapse(String s) => s.replaceAllMapped(_runs, (m) => m[1]!);

  static bool _isBlockedWord(String token) {
    final t = _normalize(token);
    if (_words.contains(t)) return true;
    for (final r in _roots) {
      if (t.startsWith(r)) return true;
    }
    // Stretched letters (3+ repeats, so "shiitake" is untouched): compare
    // collapsed forms, only for longer roots.
    final c = _collapse(t);
    if (c == t) return false;
    for (final r in _roots) {
      final rc = _collapse(r);
      if (rc.length >= 4 && c.startsWith(rc)) return true;
    }
    return false;
  }

  /// True if [text] contains a blocked word or phrase.
  static bool hasBlocked(String text) {
    if (_token.allMatches(text).any((m) => _isBlockedWord(m[0]!))) return true;
    final flat = ' ${_token.allMatches(text).map((m) => _normalize(m[0]!)).join(' ')} ';
    return _phrases.any((p) => flat.contains(' $p '));
  }

  /// [text] with blocked words replaced by asterisks (same length).
  static String mask(String text) {
    var out = text.replaceAllMapped(
      _token,
      (m) => _isBlockedWord(m[0]!) ? '*' * m[0]!.length : m[0]!,
    );
    if (hasBlocked(out)) {
      // A blocked phrase remains (e.g. "kill yourself") — mask its words.
      for (final p in _phrases) {
        final words = p.split(' ');
        final pattern = RegExp(
          words.map(RegExp.escape).join(r'[^\p{L}\p{N}]+'),
          caseSensitive: false,
          unicode: true,
        );
        out = out.replaceAllMapped(pattern, (m) => '*' * m[0]!.length);
      }
    }
    return out;
  }
}
