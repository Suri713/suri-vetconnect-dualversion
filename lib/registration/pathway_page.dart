import 'package:flutter/material.dart';
import 'package:vetconnect/app_initializer.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class PathwayPage extends StatefulWidget {
  final bool forExistingAccount;
  const PathwayPage({super.key, this.forExistingAccount = false});

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  bool _saving = false;

  Future<void> _choose(AccountPathway pathway) async {
    if (!widget.forExistingAccount) {
      Navigator.pushNamed(context, AppRoutes.register, arguments: pathway);
      return;
    }
    setState(() => _saving = true);
    final success = await Constants.firebaseHelper.setPathway(pathway);
    if (!mounted) return;
    if (!success) {
      setState(() => _saving = false);
      Constants.showPopup(
        context,
        'Unable to save pathway',
        'Please check your connection and try again.',
      );
      return;
    }
    await AppInitializer.run(context);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      appBar: AppBar(title: const Text('Choose your pathway')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageIntro(
                  title: 'Welcome to VeteranConnect',
                  subtitle:
                      'A community for veteran business owners and everyone who wants to support them.',
                ),
                const RoundedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Our mission',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'VeteranConnect helps veteran-owned businesses get discovered and connects people with ways to support veterans. Explore local businesses, find services, and give with intent.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                for (final pathway in AccountPathway.values) ...[
                  RoundedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          pathway.label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pathway.audience,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pathway == AccountPathway.veteran
                              ? 'Create a veteran business profile, appear on the map, explore businesses, find veteran-friendly careers, and donate.'
                              : 'Create your personal profile, discover veteran-owned businesses on the map, use AI search, and donate. Everyone is welcome, including veterans who do not own a business.',
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _saving ? null : () => _choose(pathway),
                          child: Text('Choose ${pathway.label.toLowerCase()}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_saving) const Center(child: CircularProgressIndicator()),
                const Text(
                  'You can change your pathway later in Settings.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
