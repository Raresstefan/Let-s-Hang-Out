/// Helpers that keep host-typed city names consistent, so "cluj", "Cluj " and
/// "Clúj" end up as one feed filter option instead of three.
library;

const _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'æ': 'ae', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd',
  'đ': 'd', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e', 'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ī': 'i', 'į': 'i', 'ı': 'i', 'ł': 'l', 'ľ': 'l', 'ñ': 'n', 'ń': 'n',
  'ň': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ō': 'o', 'ő': 'o', 'œ': 'oe', 'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's',
  'ș': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't', 'ț': 't', 'ù': 'u', 'ú': 'u',
  'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u', 'ý': 'y',
  'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

final _spaces = RegExp(r'\s+');
final _punctuation = RegExp(r"[.,'’`]");

/// Trims and collapses whitespace. A name typed entirely in lower or upper
/// case is title-cased ("new york" → "New York", "CLUJ-NAPOCA" →
/// "Cluj-Napoca"); mixed casing is kept as the host wrote it.
String normalizeCityName(String raw) {
  final s = raw.trim().replaceAll(_spaces, ' ');
  if (s.isEmpty) return s;
  if (s != s.toLowerCase() && s != s.toUpperCase()) return s;
  final lower = s.toLowerCase();
  final out = StringBuffer();
  var capitalize = true;
  for (final ch in lower.split('')) {
    out.write(capitalize ? ch.toUpperCase() : ch);
    capitalize = ch == ' ' || ch == '-';
  }
  return out.toString();
}

/// Comparison key: lower case, accents folded, punctuation dropped, so
/// "București", "bucuresti" and "Bucuresti." all match.
String cityKey(String name) {
  final lower = name.trim().toLowerCase().replaceAll(_spaces, ' ');
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(_folds[ch] ?? ch);
  }
  return out.toString().replaceAll(_punctuation, '');
}

/// Returns the existing spelling from [known] that matches [input], or
/// [input] normalized when it's a new city.
String canonicalCity(String input, Iterable<String> known) {
  final normalized = normalizeCityName(input);
  final key = cityKey(normalized);
  for (final k in known) {
    if (cityKey(k) == key) return k;
  }
  return normalized;
}

/// Most used spelling wins; on a tie prefer the accented native form
/// ("București" over "Bucuresti"), then alphabetical for stability.
bool _prefer(MapEntry<String, int> b, MapEntry<String, int> a) {
  if (b.value != a.value) return b.value > a.value;
  final bAccented = cityKey(b.key) != b.key.toLowerCase();
  final aAccented = cityKey(a.key) != a.key.toLowerCase();
  if (bAccented != aAccented) return bAccented;
  return b.key.compareTo(a.key) < 0;
}

/// A feed filter option: a city and how many upcoming activities it has.
class CityOption {
  const CityOption(this.name, this.count);

  final String name;
  final int count;

  String get key => cityKey(name);
}

/// Groups [cities] (empty entries ignored) into options sorted by activity
/// count, busiest first. Each group shows its most common spelling.
List<CityOption> cityOptionsFrom(Iterable<String> cities) {
  final groups = <String, Map<String, int>>{};
  for (final raw in cities) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final spellings = groups.putIfAbsent(cityKey(name), () => {});
    spellings[name] = (spellings[name] ?? 0) + 1;
  }
  final options = groups.values.map((spellings) {
    final best = spellings.entries.reduce((a, b) => _prefer(b, a) ? b : a);
    final total = spellings.values.fold<int>(0, (s, v) => s + v);
    return CityOption(best.key, total);
  }).toList()
    ..sort((a, b) =>
        b.count != a.count ? b.count - a.count : a.name.compareTo(b.name));
  return options;
}
