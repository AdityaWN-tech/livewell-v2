import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/country_names_en.dart';
import '../domain/auth.dart';

/// Country name shown in the picker (English only for now, D-03).
String countryName(PhoneCountry c) => countryNamesEn[c.isoCode] ?? c.isoCode;

/// The field-like button on the phone screen that shows the chosen country
/// and opens [showCountryPicker] (D-99). Not a primary action.
class CountryField extends StatelessWidget {
  const CountryField({
    super.key,
    required this.country,
    required this.onChanged,
    this.enabled = true,
  });

  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = countryName(country);
    return Semantics(
      button: true,
      label: l.phoneCountrySemantics(name, country.dialCode),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('phone-country'),
        borderRadius: LwRadius.mdAll,
        onTap: enabled
            ? () async {
                final picked = await showCountryPicker(
                  context,
                  selected: country,
                );
                if (picked != null) onChanged(picked);
              }
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l.phoneCountryLabel,
            suffixIcon: const Icon(Icons.expand_more, size: LwSize.iconMd),
          ),
          child: Text(
            '${country.flag}  $name (${country.dialCode})',
            key: const Key('phone-country-value'),
            // Wraps at large text instead of being cut off (T-REL-01).
            softWrap: true,
          ),
        ),
      ),
    );
  }
}

/// Searchable list of every country (name, flag, dial code). Returns the
/// chosen country, or null when closed without choosing.
Future<PhoneCountry?> showCountryPicker(
  BuildContext context, {
  required PhoneCountry selected,
}) => showModalBottomSheet<PhoneCountry>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _CountrySheet(selected: selected),
);

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final PhoneCountry selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  /// The two markets (D-03) first, then every other country by name.
  static final List<PhoneCountry> _ordered = () {
    final rest =
        PhoneCountry.all
            .where((c) => c != PhoneCountry.us && c != PhoneCountry.india)
            .toList()
          ..sort(
            (a, b) => _fold(countryName(a)).compareTo(_fold(countryName(b))),
          );
    return [PhoneCountry.us, PhoneCountry.india, ...rest];
  }();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final matches = filterCountries(_ordered, _query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LwSpacing.screenGutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.phoneCountryTitle, style: t.titleLarge),
                ),
                const SizedBox(height: LwSpacing.sm),
                TextField(
                  key: const Key('country-search'),
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.phoneCountrySearchHint,
                    prefixIcon: const Icon(Icons.search, size: LwSize.iconMd),
                  ),
                ),
                const SizedBox(height: LwSpacing.xs),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(LwSpacing.screenGutter),
                    child: Text(l.phoneCountryNoMatch, style: t.bodyMedium),
                  )
                : ListView.builder(
                    key: const Key('country-list'),
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final c = matches[i];
                      final isSelected = c == widget.selected;
                      return ListTile(
                        key: Key('country-${c.isoCode}'),
                        leading: Text(c.flag, style: t.titleLarge),
                        title: Text(countryName(c)),
                        trailing: Text(c.dialCode, style: t.bodyMedium),
                        selected: isSelected,
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Countries whose name, ISO code or dial code match [query] (case and
/// accents ignored; "44", "+44" and "gb" all find the United Kingdom).
List<PhoneCountry> filterCountries(List<PhoneCountry> source, String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) return source;
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  final isCode = RegExp(r'^\+?[0-9]+$').hasMatch(q);
  return source.where((c) {
    if (isCode) return c.dialCode.substring(1).startsWith(digits);
    if (c.isoCode.toLowerCase() == q) return true;
    return _fold(countryName(c)).contains(q);
  }).toList();
}

/// Lower case without common accents, so "cote" finds "Côte d’Ivoire".
String _fold(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöøùúûüýÿ’';
  const to = "aaaaaaceeeeiiiinoooooouuuuyy'";
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}
