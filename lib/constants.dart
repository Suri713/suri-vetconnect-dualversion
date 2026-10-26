import 'package:flutter/material.dart';
import 'package:vetconnect/business/business_handler.dart';
import 'package:vetconnect/services/firebase_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:vetconnect/services/location_manager.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';

abstract class AppColors {
  static const Color brandBluePrimary = ArtDecoTheme.accent;
  static const Color brandBlueLight = ArtDecoTheme.foreground;
  static const Color brandActionRed = ArtDecoTheme.accent;

  static const Color surface = ArtDecoTheme.surface;
  static const Color onSurface = ArtDecoTheme.onSurface;
  static const Color onSurfaceMuted = ArtDecoTheme.onSurfaceMuted;
  static const Color surfaceCard90 = Color(0xEE0F0F0F);
  static const Color surfaceCard92 = Color(0xF20F0F0F);

  static const Color textOnBrand = ArtDecoTheme.foreground;
  static const Color textPrimary = ArtDecoTheme.foreground;
  static const Color textMuted = ArtDecoTheme.muted;

  static const Color destructive = Color(0xFFD26868);

  static const double cardRadius = 2;
  static const double fieldRadius = 2;
  static const double buttonRadius = 2;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [ArtDecoTheme.backgroundStart, ArtDecoTheme.backgroundEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class Constants {
  static late FirebaseHelper firebaseHelper;
  static late BusinessHandler businessHandler;
  static late LocationManager locationManager;
  static Uuid uuid = Uuid();

  static void showPopup(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
            textButtonTheme: TextButtonThemeData(
              style: ArtDecoTheme.onSurfaceTextButtonStyle(),
            ),
          ),
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.onSurface, width: 1),
            ),
            title: Text(title.toUpperCase()),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      },
    );
  }
}
