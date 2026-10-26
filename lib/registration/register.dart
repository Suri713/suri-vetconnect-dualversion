import 'package:flutter/material.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetconnect/app_initializer.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/services/firebase_helper.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class RegisterPage extends StatefulWidget {
  final AccountPathway pathway;
  const RegisterPage({super.key, required this.pathway});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _enterApp() async {
    if (!mounted) return;

    if (Constants.firebaseHelper.pathway == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.choosePathway,
        (_) => false,
        arguments: true,
      );
      return;
    }
    await AppInitializer.run(context);
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.route, (_) => false);
  }

  Future<void> registerHandler(
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (_isLoading) return;
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      Constants.showPopup(
        context,
        "Invalid Email",
        "The email address you have entered is not valid. Please enter a valid email.",
      );
      return;
    }

    if (password.length < 6 || password != confirmPassword) {
      Constants.showPopup(
        context,
        "Invalid Passwords",
        "Passwords must be at least 6 characters and must match.",
      );
      return;
    }

    setState(() => _isLoading = true);

    final firebaseHelper = await FirebaseHelper.register(
      email,
      password,
      pathway: widget.pathway,
    );
    if (firebaseHelper == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Constants.showPopup(
        context,
        "Unable to Register",
        "We were unable to create your account at this time. Please try again soon.",
      );
      return;
    }

    Constants.firebaseHelper = firebaseHelper;
    await _enterApp();
  }

  Future<void> anonymousHandler() async {
    setState(() => _isLoading = true);

    final firebaseHelper = await FirebaseHelper.anonymousEntry();
    if (firebaseHelper == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Constants.showPopup(
        context,
        "Unable to Continue as Guest",
        "We could not create a guest session right now. Please try again.",
      );
      return;
    }

    Constants.firebaseHelper = firebaseHelper;
    await _enterApp();
  }

  InputDecoration _pillDecoration(String hint) {
    final radius = BorderRadius.circular(30);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.quicksand(
        color: ArtDecoTheme.onSurfaceMuted,
        fontSize: 14,
      ),
      filled: true,
      fillColor: ArtDecoTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(
          color: ArtDecoTheme.backgroundStart,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      polished: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 22),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Sign Up',
                        style: GoogleFonts.quicksand(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: ArtDecoTheme.accent,
                        ),
                      ),
                      // TextSpan(
                      //   text: 'Membership',
                      //   style: GoogleFonts.quicksand(
                      //     fontSize: 30,
                      //     fontWeight: FontWeight.w400,
                      //     color: ArtDecoTheme.accent,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.pathway.label}: ${widget.pathway.audience}. Join the VeteranConnect community.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: ArtDecoTheme.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.quicksand(
                    color: ArtDecoTheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: _pillDecoration('Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.quicksand(
                    color: ArtDecoTheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: _pillDecoration('Password'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  onSubmitted: (_) => registerHandler(
                    _emailController.text.trim(),
                    _passwordController.text,
                    _confirmPasswordController.text,
                  ),
                  style: GoogleFonts.quicksand(
                    color: ArtDecoTheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: _pillDecoration('Confirm password'),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArtDecoTheme.backgroundStart,
                      foregroundColor: ArtDecoTheme.accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => registerHandler(
                            _emailController.text.trim(),
                            _passwordController.text,
                            _confirmPasswordController.text,
                          ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ArtDecoTheme.accent,
                            ),
                          )
                        : const Text('Create account'),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.pathway == AccountPathway.user)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ArtDecoTheme.accent,
                        side: const BorderSide(color: ArtDecoTheme.accent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        textStyle: GoogleFonts.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      onPressed: _isLoading ? null : anonymousHandler,
                      child: const Text('Continue as guest'),
                    ),
                  ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: ArtDecoTheme.muted,
                    textStyle: GoogleFonts.quicksand(fontSize: 12.5),
                  ),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
