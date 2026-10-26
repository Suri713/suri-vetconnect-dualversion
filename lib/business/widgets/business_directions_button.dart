import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/services/business_directions.dart';

class BusinessDirectionsButton extends StatelessWidget {
  final Map<String, dynamic> business;

  const BusinessDirectionsButton({super.key, required this.business});

  Future<void> _openDirections(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A missing/unavailable Maps handler should not close the details sheet.
    }
    if (!context.mounted) return;
    Constants.showPopup(
      context,
      'Unable to Open Directions',
      'We could not open Maps. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = BusinessDirections.uriFor(business);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (BusinessDirections.hasApproximateLocation(business)) ...[
          Text(
            'The map pin is approximate. Confirm the business address in Maps.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed: uri == null ? null : () => _openDirections(context, uri),
          icon: const Icon(Icons.directions_rounded),
          label: const Text('Get directions'),
        ),
        if (uri == null) ...[
          const SizedBox(height: 8),
          Text(
            'An address is needed for directions.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
