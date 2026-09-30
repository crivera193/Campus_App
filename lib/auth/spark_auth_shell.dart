import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared Bonfire auth visual system: wallpaper + ember particles + brand header
/// + a warm, compact, translucent panel surface.
class SparkAuthShell extends StatelessWidget {
  const SparkAuthShell({
    super.key,
    required this.panel,
    this.footer,
    this.showBackButton = false,
    this.onBack,
  });

  final Widget panel;
  final Widget? footer;
  final bool showBackButton;
  final VoidCallback? onBack;

  static const String wallpaperAsset = 'assets/login_wallpaper.png';
  static const String sparkyAsset = 'assets/sparky.png';
  static const String bonfireLogoAsset = 'assets/Bonfire wood text.png';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: SparkAuthBackground(
        child: SafeArea(
          child: Stack(
            children: [
              if (showBackButton)
                Positioned(
                  left: 8,
                  top: 6,
                  child: _BackPillButton(onPressed: onBack),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomInset),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _SparkHeader(),
                        const SizedBox(height: 18),
                        panel,
                        if (footer != null) ...[
                          const SizedBox(height: 14),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SparkAuthBackground extends StatelessWidget {
  const SparkAuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen wallpaper; slightly boosted vibrancy so the blues/fire read
        // less muted without changing the underlying art direction.
        ColorFiltered(
          colorFilter: ColorFilter.matrix(_vibranceMatrix()),
          child: Image.asset(
            SparkAuthShell.wallpaperAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.1),
            filterQuality: FilterQuality.high,
          ),
        ),
        // Subtle deep-blue readability overlay, keeping the wallpaper blue.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x70020A16), Color(0x52020A16), Color(0x70020A16)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        const _EmberField(),
        child,
      ],
    );
  }
}

List<double> _vibranceMatrix() {
  // Small boost: +10% saturation and a tiny contrast lift.
  const s = 1.10;
  const c = 1.04;
  const t = (1.0 - c) * 0.5 * 255.0;

  final m = _saturationMatrix(s);

  // Apply contrast after saturation by scaling the RGB rows.
  return <double>[
    m[0] * c,
    m[1] * c,
    m[2] * c,
    0,
    m[4] + t,
    m[5] * c,
    m[6] * c,
    m[7] * c,
    0,
    m[9] + t,
    m[10] * c,
    m[11] * c,
    m[12] * c,
    0,
    m[14] + t,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _saturationMatrix(double s) {
  // Standard luminance-preserving saturation matrix.
  const rw = 0.213;
  const gw = 0.715;
  const bw = 0.072;

  final a = (1 - s) * rw;
  final b = (1 - s) * gw;
  final c = (1 - s) * bw;

  return <double>[
    a + s,
    b,
    c,
    0,
    0,
    a,
    b + s,
    c,
    0,
    0,
    a,
    b,
    c + s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

class SparkGlassPanel extends StatelessWidget {
  const SparkGlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xB0102233), // deep navy glass
            border: Border.all(color: const Color(0x26FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 26,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              // Soft highlight at the top edge for a "night glow" feel.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: Padding(padding: const EdgeInsets.all(18), child: child),
          ),
        ),
      ),
    );
  }
}

class SparkGradientButton extends StatelessWidget {
  const SparkGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  static const _warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF8A3D), // fire orange
      Color(0xFFFF6A4D), // coral
      Color(0xFFFF4F8D), // warm pink (small amount)
    ],
  );

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled ? onPressed : null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? _warmGradient
              : const LinearGradient(
                  colors: [Color(0x55FFFFFF), Color(0x33FFFFFF)],
                ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

InputDecorationTheme sparkAuthInputTheme() {
  const borderRadius = BorderRadius.all(Radius.circular(16));

  return const InputDecorationTheme(
    filled: true,
    fillColor: Color(0x1AFFFFFF),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: borderRadius),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0x33FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFFFF9A4A), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0x66FF5A5A)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFFFF6A4D), width: 2),
    ),
    labelStyle: TextStyle(color: Color(0xCCFFFFFF)),
    hintStyle: TextStyle(color: Color(0x80FFFFFF)),
    prefixIconColor: Color(0xCCFFFFFF),
    suffixIconColor: Color(0xCCFFFFFF),
  );
}

class _SparkHeader extends StatelessWidget {
  const _SparkHeader();

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final sparkySize = (shortestSide * 0.36).clamp(150.0, 220.0);
    final logoWidth = (shortestSide * 0.72).clamp(260.0, 420.0);
    final stackHeight = (sparkySize * 0.78).clamp(150.0, 220.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: SizedBox(
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Warm glow behind the brand lockup.
                Positioned(
                  bottom: 0,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: Container(
                      width: logoWidth * 0.9,
                      height: stackHeight * 0.9,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0x44FF8A3D), Color(0x00FF8A3D)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Sparky sits behind the wooden Bonfire logo.
                Positioned(
                  bottom: -10,
                  child: Image.asset(
                    SparkAuthShell.sparkyAsset,
                    width: sparkySize,
                    height: sparkySize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                // Wooden Bonfire logo overlays Sparky, hiding most of his body.
                Positioned(
                  bottom: 0,
                  child: Image.asset(
                    SparkAuthShell.bonfireLogoAsset,
                    width: logoWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Text(
          'Start a spark. Meet your people.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 15,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _BackPillButton extends StatelessWidget {
  const _BackPillButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x66102233),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: IconButton(
            tooltip: 'Back',
            onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Ember {
  _Ember({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.baseAlpha,
    required this.colorIndex,
  });

  double x; // 0..1
  double y; // 0..1 (0 is top)
  double radius; // logical px-ish
  double speed; // units / second (upward)
  double drift; // units / second (side)
  double baseAlpha; // 0..1
  int colorIndex;
}

class _EmberField extends StatefulWidget {
  const _EmberField();

  @override
  State<_EmberField> createState() => _EmberFieldState();
}

class _EmberFieldState extends State<_EmberField>
    with SingleTickerProviderStateMixin {
  static const int _emberCount = 26;
  static const _colors = <Color>[
    Color(0xFFFFC15A), // gold
    Color(0xFFFFA24A), // warm orange
    Color(0xFFFF8A3D), // fire orange
    Color(0xFFFFB86B), // ember peach
  ];

  final _rng = Random();
  final List<_Ember> _embers = [];

  late final AnimationController _controller;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < _emberCount; i++) {
      _embers.add(_spawn(initial: true));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..addListener(_tick);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    final now = _controller.lastElapsedDuration ?? Duration.zero;
    final deltaMicros = (now - _lastTick).inMicroseconds;

    if (deltaMicros <= 0 || deltaMicros > 200000) {
      // Skip huge jumps (app resume / jank).
      _lastTick = now;
      return;
    }

    _lastTick = now;
    final dt = deltaMicros / 1000000.0;

    for (final ember in _embers) {
      ember.y -= ember.speed * dt;
      ember.x += ember.drift * dt;

      // Gentle side drift wrap.
      if (ember.x < -0.12) ember.x = 1.12;
      if (ember.x > 1.12) ember.x = -0.12;

      // Respawn when leaving the top.
      if (ember.y < -0.18) {
        final replacement = _spawn();
        ember
          ..x = replacement.x
          ..y = replacement.y
          ..radius = replacement.radius
          ..speed = replacement.speed
          ..drift = replacement.drift
          ..baseAlpha = replacement.baseAlpha
          ..colorIndex = replacement.colorIndex;
      }
    }
  }

  _Ember _spawn({bool initial = false}) {
    // Mostly originate from the bottom-center area, like rising embers.
    final x = 0.5 + (_rng.nextDouble() - 0.5) * 0.65;
    final y = initial
        ? _rng.nextDouble() * 1.2
        : 1.12 + _rng.nextDouble() * 0.35;

    final radius = 0.9 + _rng.nextDouble() * 2.2;
    final speed = 0.05 + _rng.nextDouble() * 0.12;
    final drift = (_rng.nextDouble() - 0.5) * 0.06;
    final alpha = 0.22 + _rng.nextDouble() * 0.34;
    final colorIndex = _rng.nextInt(_colors.length);

    return _Ember(
      x: x,
      y: y,
      radius: radius,
      speed: speed,
      drift: drift,
      baseAlpha: alpha,
      colorIndex: colorIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _EmberPainter(_embers, repaint: _controller),
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.embers, {required Listenable repaint})
    : _paint = Paint()..style = PaintingStyle.fill,
      super(repaint: repaint);

  final List<_Ember> embers;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.shortestSide / 420.0).clamp(0.75, 1.25);

    for (final ember in embers) {
      final dx = ember.x * size.width;
      final dy = ember.y * size.height;

      // Fade as embers rise.
      final fade = (1.0 - (ember.y.clamp(0.0, 1.0))).clamp(0.0, 1.0);
      final a = (ember.baseAlpha * (0.55 + 0.45 * fade)).clamp(0.0, 1.0);

      final color = _EmberFieldState._colors[ember.colorIndex].withAlpha(
        (a * 255).round().clamp(0, 255),
      );
      _paint.color = color;

      canvas.drawCircle(Offset(dx, dy), ember.radius * scale, _paint);

      // Tiny soft glow.
      final glowAlpha = (a * 0.38).clamp(0.0, 1.0);
      _paint.color = color.withAlpha((glowAlpha * 255).round().clamp(0, 255));
      canvas.drawCircle(Offset(dx, dy), ember.radius * scale * 1.9, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter oldDelegate) => false;
}
