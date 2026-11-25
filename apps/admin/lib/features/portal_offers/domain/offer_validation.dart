/// Field checks shown while typing. They mirror the Core API's zod schema
/// (services/core-api/src/portal/portal-offer-model.ts), which is the real
/// check; a test keeps the host list in step.
library;

/// Hosts an offer may link to (spec 13.1).
const portalHosts = ['livewell.conciergeconnectedcare.net'];

final _control = RegExp('[\u0000-\u001f\u007f]');
final _tag = RegExp(r'^[a-z][a-z0-9_]{0,31}$');
final _reservedParam = RegExp(r'^(utm_[a-z_]*|lw_cid)$', caseSensitive: false);

String? _line(String v, int max) {
  if (v.length > max) return 'At most $max characters.';
  if (_control.hasMatch(v)) return 'One line, no special characters.';
  return null;
}

String? validateTitle(String? v) {
  final t = (v ?? '').trim();
  if (t.length < 3) return 'Enter a title (3 characters or more).';
  return _line(t, 80);
}

String? validateDescription(String? v) => _line((v ?? '').trim(), 240);

String? validatePrice(String? v, {required bool free}) {
  final t = (v ?? '').trim();
  if (free && t.isNotEmpty) return 'A free lesson has no price.';
  return _line(t, 24);
}

String? validateUrl(String? v) {
  final t = (v ?? '').trim();
  final u = Uri.tryParse(t);
  if (t.isEmpty || u == null || !u.isAbsolute) {
    return 'Enter the full link, starting with https://';
  }
  if (t.length > 500) return 'At most 500 characters.';
  if (u.scheme != 'https' ||
      !portalHosts.contains(u.host) ||
      u.hasPort ||
      u.userInfo.isNotEmpty ||
      u.hasFragment) {
    return 'Use an https link on ${portalHosts.join(' or ')}.';
  }
  if (u.queryParameters.keys.any(_reservedParam.hasMatch)) {
    return 'Remove utm_ and lw_cid parameters; the app adds them.';
  }
  return null;
}

/// "nutrition, gut_health" → ["nutrition", "gut_health"].
List<String> parseTags(String? v) => {
  for (final t in (v ?? '').split(','))
    if (t.trim().isNotEmpty) t.trim().toLowerCase(),
}.toList();

String? validateTags(String? v) {
  final tags = parseTags(v);
  if (tags.length > 8) return 'At most 8 tags.';
  final bad = tags.where((t) => !_tag.hasMatch(t));
  if (bad.isNotEmpty) {
    return 'Tags use lowercase letters, digits and _ (check "${bad.first}").';
  }
  return null;
}
