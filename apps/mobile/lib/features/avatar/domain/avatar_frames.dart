/// The avatar frame set (T-AVT-08a): 14 images of the same face that the
/// phone plays for talking, blinking and expressions, so the coach answers
/// at once and offline (NFR-02, NFR-05). Described by `avatar_frames.json`
/// (schema: packages/schemas/avatar_frames.schema.json).
library;

/// One image in the set. [id] is its name in `avatar_frames.json`.
enum AvatarFrame {
  neutral('neutral'),
  happy('happy'),
  waving('waving'),
  listening('listening'),
  calm('calm'),
  celebrating('celebrating'),
  blink('blink'),
  mouthA('mouth_A'),
  mouthI('mouth_I'),
  mouthU('mouth_U'),
  mouthE('mouth_E'),
  mouthO('mouth_O'),
  mouthClosed('mouth_closed'),

  /// A small face for lists, notifications and the widget.
  thumb('thumb');

  const AvatarFrame(this.id);
  final String id;

  static AvatarFrame? byId(String id) =>
      values.where((f) => f.id == id).firstOrNull;
}

/// The one art style (T-AVT-08 section 1).
const avatarStyle3dAdult = '3d_adult';

/// `avatar_frames.json`: which file holds each frame, at each size.
class AvatarFrameManifest {
  const AvatarFrameManifest({
    required this.avatarId,
    required this.version,
    required this.files,
    this.style = avatarStyle3dAdult,
    this.sizes = const ['2x', '3x'],
    this.canvas = 1024,
  });

  final String avatarId;
  final int version;
  final String style;

  /// The densities each frame is exported at, e.g. 2x and 3x.
  final List<String> sizes;

  /// Square canvas, in pixels, every frame shares (same face position).
  final int canvas;

  /// Frame → size → file name (relative to the manifest).
  final Map<AvatarFrame, Map<String, String>> files;

  /// Frames with no file at some size.
  List<AvatarFrame> get missing => [
    for (final f in AvatarFrame.values)
      if (sizes.any((s) => files[f]?[s] == null)) f,
  ];

  bool get complete => missing.isEmpty;

  /// The file for [frame] at the size nearest [devicePixelRatio], if any.
  String? fileFor(AvatarFrame frame, {double devicePixelRatio = 3}) {
    final byFrame = files[frame];
    if (byFrame == null || byFrame.isEmpty) return null;
    final want = '${devicePixelRatio.clamp(2, 3).round()}x';
    return byFrame[want] ?? byFrame.values.first;
  }

  Map<String, Object> toJson() => {
    'avatar_id': avatarId,
    'version': version,
    'style': style,
    'canvas': {'width': canvas, 'height': canvas},
    'sizes': sizes,
    'frames': {for (final e in files.entries) e.key.id: e.value},
  };

  /// Reads a manifest; throws [FormatException] when it isn't one.
  static AvatarFrameManifest fromJson(Map<String, dynamic> m) {
    final id = m['avatar_id'];
    final version = m['version'];
    final frames = m['frames'];
    if (id is! String || id.isEmpty || version is! int || frames is! Map) {
      throw const FormatException('Not an avatar_frames.json');
    }
    if (m['style'] != avatarStyle3dAdult) {
      throw FormatException('Unknown avatar style: ${m['style']}');
    }
    final canvas = m['canvas'];
    return AvatarFrameManifest(
      avatarId: id,
      version: version,
      sizes: [
        for (final s in (m['sizes'] as List? ?? const ['2x', '3x']))
          if (s is String) s,
      ],
      canvas: canvas is Map && canvas['width'] is int
          ? canvas['width'] as int
          : 1024,
      files: {
        for (final e in frames.entries)
          if (AvatarFrame.byId('${e.key}') case final f?)
            if (e.value is Map)
              f: {
                for (final s in (e.value as Map).entries)
                  if (s.value is String && _safe(s.value as String))
                    '${s.key}': s.value as String,
              },
      },
    );
  }

  /// A plain file name: no folders, so a manifest can't point elsewhere.
  static bool _safe(String name) =>
      RegExp(r'^[A-Za-z0-9_@.\-]+$').hasMatch(name) && !name.contains('..');
}
