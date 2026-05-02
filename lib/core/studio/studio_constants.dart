/// Canonical genre ids stored in album/track JSON (labels via `studio.genre.<id>`).
const List<String> studioGenreIds = [
  'pop',
  'rock',
  'electronic',
  'hip_hop',
  'rb',
  'jazz',
  'classical',
  'ambient',
  'lo_fi',
  'metal',
  'punk',
  'indie',
  'folk',
  'country',
  'reggae',
  'drum_bass',
  'house',
  'techno',
  'trance',
  'dubstep',
  'other',
];

/// Maps normalized label → canonical id (English/Russian variants + legacy UI strings).
const Map<String, String> studioGenreAliases = {
  // canonical ids (lower snake already normalized via _aliasKey)
  'pop': 'pop',
  'rock': 'rock',
  'electronic': 'electronic',
  'hip_hop': 'hip_hop',
  'rb': 'rb',
  'jazz': 'jazz',
  'classical': 'classical',
  'ambient': 'ambient',
  'lo_fi': 'lo_fi',
  'metal': 'metal',
  'punk': 'punk',
  'indie': 'indie',
  'folk': 'folk',
  'country': 'country',
  'reggae': 'reggae',
  'drum_bass': 'drum_bass',
  'house': 'house',
  'techno': 'techno',
  'trance': 'trance',
  'dubstep': 'dubstep',
  'other': 'other',
  // legacy English chips (older builds)
  'hip-hop': 'hip_hop',
  'hip hop': 'hip_hop',
  'hiphop': 'hip_hop',
  'r&b': 'rb',
  'r & b': 'rb',
  'rnb': 'rb',
  'lo-fi': 'lo_fi',
  'lo fi': 'lo_fi',
  'drum & bass': 'drum_bass',
  'drum and bass': 'drum_bass',
  // Russian
  'поп': 'pop',
  'рок': 'rock',
  'электроника': 'electronic',
  'хип-хоп': 'hip_hop',
  'хип хоп': 'hip_hop',
  'рэндби': 'rb',
  'джаз': 'jazz',
  'классика': 'classical',
  'классическая': 'classical',
  'эмбиент': 'ambient',
  'метал': 'metal',
  'металл': 'metal',
  'панк': 'punk',
  'инди': 'indie',
  'фолк': 'folk',
  'кантри': 'country',
  'регги': 'reggae',
  'хаус': 'house',
  'техно': 'techno',
  'транс': 'trance',
  'дабстеп': 'dubstep',
  'другое': 'other',
};

String _aliasKey(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll('ё', 'е');
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

/// Returns canonical genre id if recognized, otherwise `null`.
String? normalizeStudioGenreId(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (studioGenreIds.contains(t)) return t;
  final key = _aliasKey(t);
  return studioGenreAliases[key];
}

/// Normalizes a list of stored genres (legacy labels or ids) to canonical ids.
List<String> normalizeStudioGenreList(List<String> stored) {
  final out = <String>{};
  for (final g in stored) {
    final id = normalizeStudioGenreId(g);
    if (id != null && studioGenreIds.contains(id)) {
      out.add(id);
    }
  }
  return out.toList();
}
