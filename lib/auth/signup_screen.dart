import '../utils/username_generator.dart';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorMessage;

  final RegExp _utrgvEmailPattern = RegExp(
    r'^[^@\s]+@utrgv\.edu$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      // Preserve the provisional username metadata used by the existing
      // profile-creation path, while marking it pending so AuthGate still
      // requires the user's final username selection.
      final provisionalUsername = await UsernameGenerator.generateUnique();

      final response = await _supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {'username': provisionalUsername, 'username_pending': true},
      );

      if (response.user == null) {
        throw StateError('Supabase did not create the account.');
      }

      if (!mounted) return;

      if (response.session != null) {
        // Email confirmation is currently disabled, so the student
        // receives a session immediately.
        //
        // Return to the root route where AuthGate can display
        // the authenticated part of the app.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Check your email'),
              content: Text(
                'Your account was created. Confirm your email, then choose your campus username when you sign in.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Unable to create the account profile.\n${error.message}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to create the account.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final themed = Theme.of(context).copyWith(
      inputDecorationTheme: _signupInputTheme(),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        body: _SignupBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomInset),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 26),
                          const _SignupHeader(),
                          const SizedBox(height: 26),
                          _SignupPanel(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.newUsername,
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'UTRGV email',
                                      hintText: 'student@utrgv.edu',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: (value) {
                                      final email = value?.trim() ?? '';

                                      if (email.isEmpty) {
                                        return 'Enter your UTRGV email.';
                                      }

                                      if (!_utrgvEmailPattern.hasMatch(email)) {
                                        return 'Email must end in @utrgv.edu.';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Create a password.';
                                      }

                                      if (value.length < 8) {
                                        return 'Use at least 8 characters.';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmation,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    onFieldSubmitted: (_) {
                                      if (!_isLoading) {
                                        _createAccount();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Confirm password',
                                      prefixIcon: const Icon(
                                        Icons.lock_reset_outlined,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _obscureConfirmation
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmation =
                                                !_obscureConfirmation;
                                          });
                                        },
                                        icon: Icon(
                                          _obscureConfirmation
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter the password again.';
                                      }

                                      if (value != _passwordController.text) {
                                        return 'The passwords do not match.';
                                      }

                                      return null;
                                    },
                                  ),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC2C2),
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xAA000000),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  _SignupPrimaryButton(
                                    enabled: !_isLoading,
                                    onPressed: _isLoading
                                        ? null
                                        : _createAccount,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Create Student Account',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 6,
                  child: _BackPillButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecorationTheme _signupInputTheme() {
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
      borderSide: BorderSide(color: Color(0xFFB96BFF), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0x66FFC2C2)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0xFFFF7A7A), width: 2),
    ),
    labelStyle: TextStyle(color: Color(0xCCFFFFFF)),
    hintStyle: TextStyle(color: Color(0x80FFFFFF)),
    prefixIconColor: Color(0xCCFFFFFF),
    suffixIconColor: Color(0xCCFFFFFF),
  );
}

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _GradientTitle('Bonfire'),
        SizedBox(height: 8),
        Text(
          'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xE6FFFFFF),
            fontWeight: FontWeight.w700,
            fontSize: 16,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle(this.text);
  final String text;

  static const _titleGradient = LinearGradient(
    colors: [
      Color(0xFFFF9A3D),
      Color(0xFFFF4F8D),
      Color(0xFF7C4DFF),
      Color(0xFF3D8BFF),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _titleGradient.createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          shadows: [Shadow(color: Color(0x66000000), blurRadius: 18)],
        ),
      ),
    );
  }
}

class _SignupPanel extends StatelessWidget {
  const _SignupPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x8010182E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

class _SignupPrimaryButton extends StatelessWidget {
  const _SignupPrimaryButton({
    required this.onPressed,
    required this.child,
    required this.enabled,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C4DFF), Color(0xFFFF4F8D), Color(0xFFFF9A3D)],
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? _gradient
              : const LinearGradient(
                  colors: [Color(0x55FFFFFF), Color(0x33FFFFFF)],
                ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
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

class _BackPillButton extends StatelessWidget {
  const _BackPillButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x6610182E),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: IconButton(
            tooltip: 'Back',
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SignupBackground extends StatelessWidget {
  const _SignupBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [const _SignupGradient(), const _ColorSparkField(), child],
    );
  }
}

class _SignupGradient extends StatelessWidget {
  const _SignupGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B1038), // deep purple
            Color(0xFF0A2A5A), // deep blue
            Color(0xFF2C1340), // magenta-purple
            Color(0xFF0A2A5A), // return to blue
          ],
          stops: [0.0, 0.45, 0.75, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.2, -0.5),
            radius: 1.2,
            colors: [
              Color(0x3316B8FF), // soft cyan glow
              Color(0x0016B8FF),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.baseAlpha,
    required this.colorIndex,
  });

  double x; // 0..1
  double y; // 0..1
  double radius;
  double speed;
  double drift;
  double baseAlpha;
  int colorIndex;
}

class _ColorSparkField extends StatefulWidget {
  const _ColorSparkField();

  @override
  State<_ColorSparkField> createState() => _ColorSparkFieldState();
}

class _ColorSparkFieldState extends State<_ColorSparkField>
    with SingleTickerProviderStateMixin {
  static const int _sparkCount = 34;
  static const _colors = <Color>[
    Color(0xFFFF9A3D), // orange
    Color(0xFFFF4F8D), // pink
    Color(0xFF7C4DFF), // purple
    Color(0xFF3D8BFF), // blue
    Color(0xFF5EE7FF), // cyan
  ];

  final _rng = Random();
  final List<_Spark> _sparks = [];

  late final AnimationController _controller;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < _sparkCount; i++) {
      _sparks.add(_spawn(initial: true));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
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
      _lastTick = now;
      return;
    }

    _lastTick = now;
    final dt = deltaMicros / 1000000.0;

    for (final spark in _sparks) {
      spark.y -= spark.speed * dt;
      spark.x += spark.drift * dt;

      if (spark.x < -0.15) spark.x = 1.15;
      if (spark.x > 1.15) spark.x = -0.15;

      if (spark.y < -0.18) {
        final replacement = _spawn();
        spark
          ..x = replacement.x
          ..y = replacement.y
          ..radius = replacement.radius
          ..speed = replacement.speed
          ..drift = replacement.drift
          ..baseAlpha = replacement.baseAlpha
          ..colorIndex = replacement.colorIndex;
      }
    }

    // Paint is driven by the controller; no setState needed.
  }

  _Spark _spawn({bool initial = false}) {
    final x = _rng.nextDouble() * 1.2 - 0.1;
    final y = initial
        ? _rng.nextDouble() * 1.2
        : 1.08 + _rng.nextDouble() * 0.35;

    final radius = 0.9 + _rng.nextDouble() * 2.6;
    final speed = 0.06 + _rng.nextDouble() * 0.14;
    final drift = (_rng.nextDouble() - 0.5) * 0.09;
    final alpha = 0.18 + _rng.nextDouble() * 0.30;
    final colorIndex = _rng.nextInt(_colors.length);

    return _Spark(
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SparkPainter(_sparks, _colors, _controller.value),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks, this.palette, this.t);

  final List<_Spark> sparks;
  final List<Color> palette;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in sparks) {
      final dx = spark.x * size.width;
      final dy = spark.y * size.height;

      final phase = (t * 6.2831853) + (spark.x * 3.4);
      final pulse = 0.70 + sin(phase) * 0.30;
      final alpha = (spark.baseAlpha * pulse).clamp(0.0, 1.0);

      final color = palette[spark.colorIndex].withValues(alpha: alpha);

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(dx, dy), spark.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.t != t;
}
