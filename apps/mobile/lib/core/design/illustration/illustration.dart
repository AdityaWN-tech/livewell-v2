import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// One entry of assets/illustrations/illustrations.json (T-UI-02b).
class IllustrationEntry {
  const IllustrationEntry({
    required this.id,
    required this.kind,
    required this.alt,
    required this.decorative,
    required this.tint,
    required this.fallbackIcon,
    required this.status,
    this.file,
    this.fileDark,
    this.source,
    this.licence,
  });

  final String id;

  /// character, scene, lesson, icon, empty or feature.
  final String kind;

  /// Read by screen readers; empty for decorative art.
  final String alt;

  /// Decoration only: hidden from screen readers.
  final bool decorative;

  /// Palette tint name for the placeholder (mint, lime, lavender, ...).
  final String tint;
  final String fallbackIcon;

  /// placeholder or final.
  final String status;

  /// Asset file names in assets/illustrations/, null until the art exists.
  final String? file;
  final String? fileDark;
  final String? source;
  final String? licence;

  bool get isFinal => status == 'final';

  factory IllustrationEntry.fromMap(Map<String, dynamic> m) =>
      IllustrationEntry(
        id: m['id'] as String,
        kind: m['kind'] as String,
        alt: (m['alt'] as String?) ?? '',
        decorative: m['decorative'] == true,
        tint: (m['tint'] as String?) ?? 'mint',
        fallbackIcon: (m['fallback_icon'] as String?) ?? 'eco',
        status: (m['status'] as String?) ?? 'placeholder',
        file: m['file'] as String?,
        fileDark: m['file_dark'] as String?,
        source: m['source'] as String?,
        licence: m['licence'] as String?,
      );
}

/// Every illustration by id, loaded once from the manifest.
class IllustrationCatalog {
  IllustrationCatalog(Iterable<IllustrationEntry> entries)
    : _byId = {for (final e in entries) e.id: e};

  final Map<String, IllustrationEntry> _byId;

  static const manifest = 'assets/illustrations/illustrations.json';
  static const folder = 'assets/illustrations/';

  IllustrationEntry? operator [](String id) => _byId[id];
  Iterable<IllustrationEntry> get entries => _byId.values;

  factory IllustrationCatalog.parse(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return IllustrationCatalog(
      (m['items'] as List).cast<Map<String, dynamic>>().map(
        IllustrationEntry.fromMap,
      ),
    );
  }

  static Future<IllustrationCatalog>? _loading;

  /// Tests set this to skip the asset bundle.
  @visibleForTesting
  static IllustrationCatalog? debugValue;

  static IllustrationCatalog? _current;

  /// The catalog once loaded (no flash of placeholders on later screens).
  static IllustrationCatalog? get current => debugValue ?? _current;

  static Future<IllustrationCatalog> load() {
    if (debugValue case final c?) return Future.value(c);
    return _loading ??= rootBundle
        .loadString(manifest)
        .then(IllustrationCatalog.parse)
        .then((c) => _current = c)
        // A broken manifest must never break a screen: placeholders only.
        .catchError((Object _) => IllustrationCatalog(const []));
  }
}

/// Fallback icons by manifest name: a fixed set, checked by a test.
const illustrationIcons = <String, IconData>{
  'person': Icons.person_outline,
  'sun': Icons.wb_sunny_outlined,
  'leaf': Icons.eco_outlined,
  'eco': Icons.eco_outlined,
  'landscape': Icons.landscape_outlined,
  'air': Icons.air,
  'spa': Icons.spa_outlined,
  'bedtime': Icons.bedtime_outlined,
  'directions_walk': Icons.directions_walk,
  'restaurant': Icons.restaurant_outlined,
  'sentiment_satisfied': Icons.sentiment_satisfied_outlined,
  'bolt': Icons.bolt_outlined,
  'local_fire_department': Icons.local_fire_department_outlined,
  'water_drop': Icons.water_drop_outlined,
  'flag': Icons.flag_outlined,
  'edit_note': Icons.edit_note,
  'insights': Icons.insights_outlined,
  'cloud_off': Icons.cloud_off_outlined,
  'auto_awesome': Icons.auto_awesome_outlined,
  'notifications': Icons.notifications_none,
  'luggage': Icons.luggage_outlined,
  'school': Icons.school_outlined,
  'watch': Icons.watch_outlined,
};

/// An illustration by manifest id (T-UI-02b). Shows the light or dark file
/// when it exists; otherwise (placeholder, missing file, unknown id) a soft
/// tinted shape with a small icon, so screens never show a broken image.
class Illustration extends StatelessWidget {
  const Illustration(
    this.id, {
    super.key,
    this.width,
    this.height,
    this.semanticLabel,
    this.fit = BoxFit.contain,
  });

  final String id;
  final double? width;
  final double? height;

  /// Overrides the manifest's alt text (for example a translated label).
  final String? semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => FutureBuilder<IllustrationCatalog>(
    future: IllustrationCatalog.load(),
    initialData: IllustrationCatalog.current,
    builder: (context, snap) {
      final e = snap.data?[id];
      final dark = Theme.of(context).brightness == Brightness.dark;
      final file = e == null ? null : (dark ? e.fileDark ?? e.file : e.file);
      final fallback = IllustrationPlaceholder(
        tint: e?.tint ?? 'mint',
        icon: illustrationIcons[e?.fallbackIcon] ?? Icons.eco_outlined,
        width: width,
        height: height,
      );
      final art = file == null
          ? fallback
          : Image.asset(
              '${IllustrationCatalog.folder}$file',
              width: width,
              height: height,
              fit: fit,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            );
      final label = semanticLabel ?? e?.alt ?? '';
      if (((e?.decorative ?? true) && semanticLabel == null) || label.isEmpty) {
        return ExcludeSemantics(child: art);
      }
      return Semantics(
        image: true,
        label: label,
        container: true,
        excludeSemantics: true,
        child: art,
      );
    },
  );
}

/// The placeholder drawn until final art exists: a soft pastel shape with a
/// leaf and a small icon, in the illustrated style.
class IllustrationPlaceholder extends StatelessWidget {
  const IllustrationPlaceholder({
    super.key,
    required this.tint,
    required this.icon,
    this.width,
    this.height,
  });

  final String tint;
  final IconData icon;
  final double? width;
  final double? height;

  static Color tintOf(LwPalette p, String name) => switch (name) {
    'lime' => p.lime,
    'lavender' => p.lavender,
    'peach' => p.peach,
    'sky' => p.sky,
    'butter' => p.butter,
    'rose' => p.rose,
    _ => p.mint,
  };

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = [
            c.maxWidth.isFinite ? c.maxWidth : LwSize.minTapTarget * 2,
            c.maxHeight.isFinite ? c.maxHeight : LwSize.minTapTarget * 2,
          ].reduce((a, b) => a < b ? a : b);
          return CustomPaint(
            painter: _BlobPainter(
              fill: tintOf(p, tint),
              leaf: p.accent.withValues(alpha: 0.35),
            ),
            child: Center(
              child: Icon(icon, size: side * 0.36, color: p.primaryDark),
            ),
          );
        },
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.fill, required this.leaf});

  final Color fill;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.3),
    );
    canvas.drawRRect(r, Paint()..color = fill);
    // Two small leaves in the bottom-left corner.
    final s = size.shortestSide * 0.22;
    final paint = Paint()..color = leaf;
    for (final (dx, angle) in [(0.0, -0.5), (s * 0.55, 0.3)]) {
      canvas
        ..save()
        ..translate(s * 0.6 + dx, size.height - s * 0.5)
        ..rotate(angle)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * 0.5, height: s),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.fill != fill || old.leaf != leaf;
}
