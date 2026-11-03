import 'package:flutter/material.dart';

import '../tokens.dart';

/// Logo-only "Continue with Google" / "Continue with Apple" buttons
/// (T-ONB-03a). Official artwork, never recoloured or distorted; sources
/// and pairing rules in docs/brand/social/README.md. 48 dp, round, with an
/// accessible label.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton.google({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _brand = _Brand.google;

  const SocialSignInButton.apple({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _brand = _Brand.apple;

  final String label;
  final VoidCallback? onPressed;
  final _Brand _brand;

  static const double size = LwSize.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Widget logo = switch (_brand) {
      // The kit's light button on light screens, dark button on dark ones.
      _Brand.google => Image.asset(
        dark
            ? 'assets/brand/social/google_dark.png'
            : 'assets/brand/social/google_light.png',
        width: size,
        height: size,
        // Scale the kit's 40 dp button evenly to 48 dp (no distortion).
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      // Apple: black button on light screens, white button on dark ones.
      _Brand.apple => CustomPaint(
        size: const Size.square(size),
        painter: _AppleLogoPainter(onDark: dark),
      ),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: logo,
          ),
        ),
      ),
    );
  }
}

enum _Brand { google, apple }

/// Apple's logo-only artwork (Sign in with Apple Logo, "Square", 56 x 56
/// with the button square at 6..50), drawn in a circular mask as Apple's
/// guidelines allow. The path is copied unchanged from
/// docs/brand/social/apple-logo-black-on-white-square.svg.
class _AppleLogoPainter extends CustomPainter {
  _AppleLogoPainter({required this.onDark});

  final bool onDark;

  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);

  static const _logo =
      'M28.2226562,20.3846154 C29.0546875,20.3846154 30.0976562,19.8048315 '
      '30.71875,19.0317864 C31.28125,18.3312142 31.6914062,17.352829 '
      '31.6914062,16.3744437 C31.6914062,16.2415766 31.6796875,16.1087095 '
      '31.65625,16 C30.7304687,16.0362365 29.6171875,16.640178 '
      '28.9492187,17.4494596 C28.421875,18.06548 27.9414062,19.0317864 '
      '27.9414062,20.0222505 C27.9414062,20.1671964 27.9648438,20.3121424 '
      '27.9765625,20.3604577 C28.0351562,20.3725366 28.1289062,20.3846154 '
      '28.2226562,20.3846154 Z M25.2929688,35 C26.4296875,35 '
      '26.9335938,34.214876 28.3515625,34.214876 C29.7929688,34.214876 '
      '30.109375,34.9758423 31.375,34.9758423 C32.6171875,34.9758423 '
      '33.4492188,33.792117 34.234375,32.6325493 C35.1132812,31.3038779 '
      '35.4765625,29.9993643 35.5,29.9389701 C35.4179688,29.9148125 '
      '33.0390625,28.9122695 33.0390625,26.0979021 C33.0390625,23.6579784 '
      '34.9140625,22.5588048 35.0195312,22.474253 C33.7773438,20.6382708 '
      '31.890625,20.5899555 31.375,20.5899555 C29.9804688,20.5899555 '
      '28.84375,21.4596313 28.1289062,21.4596313 C27.3554688,21.4596313 '
      '26.3359375,20.6382708 25.1289062,20.6382708 C22.8320312,20.6382708 '
      '20.5,22.5950413 20.5,26.2911634 C20.5,28.5861411 21.3671875,31.013986 '
      '22.4335938,32.5842339 C23.3476562,33.9129053 24.1445312,35 '
      '25.2929688,35 Z';

  /// Parses the absolute M / C / Z commands the artwork uses.
  static Path parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[MCZ]|-?[0-9.]+').allMatches(d).map((m) => m[0]!);
    String? cmd;
    final nums = <double>[];
    void flush() {
      if (cmd == 'M' && nums.length >= 2) path.moveTo(nums[0], nums[1]);
      if (cmd == 'C') {
        for (var i = 0; i + 5 < nums.length; i += 6) {
          path.cubicTo(
            nums[i],
            nums[i + 1],
            nums[i + 2],
            nums[i + 3],
            nums[i + 4],
            nums[i + 5],
          );
        }
      }
      nums.clear();
    }

    for (final t in tokens) {
      if (t == 'M' || t == 'C' || t == 'Z') {
        flush();
        if (t == 'Z') path.close();
        cmd = t;
      } else {
        nums.add(double.parse(t));
      }
    }
    flush();
    return path;
  }

  static final _path = parse(_logo);

  @override
  void paint(Canvas canvas, Size size) {
    // The artwork's button square is 44 units wide, starting at 6.
    final scale = size.width / 44;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-6, -6);
    canvas.drawCircle(
      const Offset(28, 28),
      22,
      Paint()..color = onDark ? _white : _black,
    );
    canvas.drawPath(_path, Paint()..color = onDark ? _black : _white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AppleLogoPainter old) => old.onDark != onDark;
}
