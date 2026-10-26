import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

  /// PayPal.me link behind the QR code. Leave empty and the page shows the QR
  /// on its own; set it and a tappable button appears, which matters because
  /// someone reading this page on their phone cannot scan their own screen.
  static const String payPalUrl = '';

  static const String charityName = 'Wounded Warrior Project';

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      Constants.showPopup(
        context,
        'Unable to Open Link',
        'We could not open this link right now.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      appBar: AppBar(title: const Text('Donations')),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(context),
                  _qrCard(context),
                  const SizedBox(height: 24),
                  _disclosureCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context) {
    return const PageIntro(
      title: 'Want to Donate?',
      subtitle:
          '80% of proceeds go to $charityName. '
          '20% helps us maintain the VeteranConnect app!',
    );
  }

  Widget _qrCard(BuildContext context) {
    return RoundedCard(
      child: Column(
        children: [
          Text(
            'Give with PayPal',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ArtDecoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan this code with your phone camera or the PayPal app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              height: 1.4,
              color: ArtDecoTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/paypal_suri.png',
              width: 260,
              height: 260,
              fit: BoxFit.contain,
              // The QR is the whole point of this screen, so say plainly when
              // it cannot be shown rather than rendering a broken-image box.
              errorBuilder: (context, error, stackTrace) => Container(
                width: 260,
                height: 260,
                alignment: Alignment.center,
                color: ArtDecoTheme.fieldFill,
                child: Text(
                  payPalUrl.isNotEmpty
                      ? 'QR code unavailable.\nUse the link below instead.'
                      : 'QR code unavailable.\nPlease try again later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: ArtDecoTheme.onSurfaceMuted,
                  ),
                ),
              ),
            ),
          ),
          if (payPalUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openLink(context, payPalUrl),
                icon: const Icon(CupertinoIcons.arrow_up_right_square),
                label: const Text('Open PayPal'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _disclosureCard() {
    return RoundedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ArtDecoTheme.onSurfaceMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How this works',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ArtDecoTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Donations made through the QR code are received by '
                  'VeteranConnect. 80% of proceeds are forwarded to $charityName, '
                  'and 20% is retained by VeteranConnect to help maintain the app.',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    height: 1.45,
                    color: ArtDecoTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
