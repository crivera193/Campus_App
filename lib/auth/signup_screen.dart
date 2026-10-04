import '../utils/username_generator.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Styling ---
class _WarmPalette {
  static const bg = Color(0xFF2A1B15);
  static const surface = Color(0xFF3A261F);
  static const border = Color(0x665A4034);
  static const text = Color(0xFFF5EDE3);
  static const textMuted = Color(0xFFD7C7B8);
  static const accent = Color(0xFFFF9A3D);
  static const error = Color(0xFFF0A15B);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // --- Form & Auth ---
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
    // --- Theme ---
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final themed = Theme.of(context).copyWith(
      inputDecorationTheme: _signupInputTheme(),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: _WarmPalette.text, displayColor: _WarmPalette.text),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        // --- Layout ---
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
                          Form(
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
                                  style: const TextStyle(
                                    color: _WarmPalette.text,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: const TextStyle(
                                    color: _WarmPalette.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
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
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmation,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: const TextStyle(
                                    color: _WarmPalette.text,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                  const SizedBox(height: 14),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _WarmPalette.error,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _SignupPrimaryButton(
                                  enabled: !_isLoading,
                                  onPressed:
                                      _isLoading ? null : _createAccount,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _WarmPalette.text,
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
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 0,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _WarmPalette.text,
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

// --- Form Styles ---
InputDecorationTheme _signupInputTheme() {
  const borderRadius = BorderRadius.all(Radius.circular(14));

  return const InputDecorationTheme(
    filled: true,
    fillColor: _WarmPalette.surface,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: borderRadius),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _WarmPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _WarmPalette.accent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Color(0x66F0A15B)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _WarmPalette.error, width: 2),
    ),
    labelStyle: TextStyle(color: _WarmPalette.textMuted),
    hintStyle: TextStyle(color: Color(0x99D7C7B8)),
    prefixIconColor: _WarmPalette.textMuted,
    suffixIconColor: _WarmPalette.textMuted,
    errorStyle: TextStyle(color: _WarmPalette.error, fontWeight: FontWeight.w700),
  );
}

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _BonfireTitle('Bonfire'),
        SizedBox(height: 8),
        Text(
          'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _WarmPalette.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _BonfireTitle extends StatelessWidget {
  const _BonfireTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _WarmPalette.accent,
        fontSize: 40,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        shadows: [Shadow(color: Color(0x66000000), blurRadius: 12)],
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _WarmPalette.accent,
          disabledBackgroundColor: const Color(0x99B9793E),
          foregroundColor: _WarmPalette.text,
          shadowColor: const Color(0x40000000),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SignupBackground extends StatelessWidget {
  const _SignupBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _WarmPalette.bg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _WarmPalette.bg,
            Color(0xFF241610),
          ],
        ),
      ),
      child: child,
    );
  }
}
