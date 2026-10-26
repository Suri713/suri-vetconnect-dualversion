import 'package:flutter/material.dart';
import 'package:vetconnect/business/business_handler.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/services/location_manager.dart';

class AppInitializer {
  static Future<void> run(BuildContext context) async {
    final businessHandler = await BusinessHandler.init();
    if (!context.mounted) return;

    if (businessHandler != null) {
      Constants.businessHandler = businessHandler;
    } else {
      debugPrint("Unable to initialize business handler.");
    }

    Constants.locationManager = await LocationManager.init();
    if (!context.mounted) return;

    await _handleLocationReadiness(context);
  }

  static Future<void> _handleLocationReadiness(BuildContext context) async {
    final LocationAccessStatus accessStatus = await Constants.locationManager
        .refreshLocationAccess();
    if (!context.mounted || accessStatus == LocationAccessStatus.available) {
      return;
    }

    if (accessStatus == LocationAccessStatus.serviceDisabled) {
      final bool openSettings =
          await _showActionDialog(
            context,
            title: 'Location Service Disabled',
            message:
                'Location services are disabled. Open your device location settings to continue.',
            actionLabel: 'Open Settings',
          ) ??
          false;

      if (openSettings) {
        await Constants.locationManager.openLocationSettings();
      }
      return;
    }

    if (accessStatus == LocationAccessStatus.deniedForever) {
      final bool openSettings =
          await _showActionDialog(
            context,
            title: 'Location Permission Blocked',
            message:
                'Location permission is permanently denied. Open app settings to allow access.',
            actionLabel: 'Open App Settings',
          ) ??
          false;

      if (openSettings) {
        await Constants.locationManager.openAppSettings();
      }
      return;
    }

    if (accessStatus == LocationAccessStatus.denied) {
      await _showActionDialog(
        context,
        title: 'Location Permission Disabled',
        message:
            'Location access is disabled. You can still continue, but map-based features may be limited.',
        actionLabel: 'Continue',
        showCancel: false,
      );
    }
  }

  static Future<bool?> _showActionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool showCancel = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title.toUpperCase()),
        content: Text(message),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NOT NOW'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
