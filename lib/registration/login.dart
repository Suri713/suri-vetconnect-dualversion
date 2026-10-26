import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetconnect/app_initializer.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/services/firebase_helper.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginHandler(String email, String password) async {
    final isEmailValid =
        email.isNotEmpty && email.contains('@') && email.contains('.');
    final isPasswordValid = password.length >= 6;

    if (!isEmailValid || !isPasswordValid) {
      Constants.showPopup(
        context,
        "Incorrect Information",
        "Please enter a valid email and a password longer than six characters.",
      );
      return;
    }

    setState(() => _isLoading = true);

    final firebaseHelper = await FirebaseHelper.login(email, password);
    if (firebaseHelper == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Constants.showPopup(
        context,
        "Incorrect Credentials",
        "The email or password you inputted is incorrect. Please carefully try again.",
      );
      return;
    }

    Constants.firebaseHelper = firebaseHelper;
    if (!mounted) return;

    if (firebaseHelper.pathway == null) {
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
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ArtDecoTheme.accent, width: 1.6),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: ArtDecoTheme.accent,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 22),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Veteran',
                        style: GoogleFonts.quicksand(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: ArtDecoTheme.accent,
                        ),
                      ),
                      TextSpan(
                        text: 'Connect',
                        style: GoogleFonts.quicksand(
                          fontSize: 30,
                          fontWeight: FontWeight.w400,
                          color: ArtDecoTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Closing the gap between veteran-owned businesses and Americans',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: ArtDecoTheme.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
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
                  onSubmitted: (_) => loginHandler(
                    _emailController.text.trim(),
                    _passwordController.text,
                  ),
                  style: GoogleFonts.quicksand(
                    color: ArtDecoTheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: _pillDecoration('Password'),
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
                        : () => loginHandler(
                            _emailController.text.trim(),
                            _passwordController.text,
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
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.choosePathway,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: ArtDecoTheme.muted,
                    textStyle: GoogleFonts.quicksand(fontSize: 12.5),
                  ),
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
