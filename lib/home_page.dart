import 'package:flutter/cupertino.dart';
import 'package:vetconnect/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final infoCards = [
      (
        icon: CupertinoIcons.add_circled,
        title: Constants.firebaseHelper.canManageBusiness
            ? 'Create your veteran business profile'
            : 'Create your profile',
        description: Constants.firebaseHelper.canManageBusiness
            ? 'Use the Create tab to add your veteran-owned business, location, and photos so customers can find and support your work.'
            : 'Use Settings to personalize your name and profile. Choose your interests on the map to discover businesses you might like.',
      ),
      (
        icon: CupertinoIcons.search,
        title: 'Discover Veteran-Owned Services',
        description:
            'Use search tools to quickly find local businesses by category, service, or need and view helpful details.',
      ),
      (
        icon: CupertinoIcons.map,
        title: 'Explore your veteran community',
        description:
            'Use the map view to explore business locations with a local-first community focus.',
      ),
      (
        icon: CupertinoIcons.heart,
        title: 'Support veterans with intent',
        description:
            'Every visit, referral, and purchase strengthens veteran entrepreneurs and the communities around them.',
      ),
      if (Constants.firebaseHelper.canManageBusiness)
        (
          icon: CupertinoIcons.briefcase,
          title: 'Find veteran-friendly careers',
          description:
              'Browse conservation careers and other veteran-friendly job resources in the Careers tab.',
        ),
    ];

    return ArtDecoScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 44),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: PageIntro(
                        title: 'Features',
                        subtitle:
                            'Discover, connect, and support veteran-owned businesses in your community.',
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.settings),
                      icon: const Icon(
                        CupertinoIcons.gear_alt,
                        color: ArtDecoTheme.accent,
                      ),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < infoCards.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 62,
                      color: ArtDecoTheme.accent.withAlpha(28),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ArtDecoTheme.accent.withAlpha(18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ArtDecoTheme.accent.withAlpha(30),
                            ),
                          ),
                          child: Icon(
                            infoCards[i].icon,
                            color: ArtDecoTheme.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                infoCards[i].title,
                                style: GoogleFonts.quicksand(
                                  fontSize: 18,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: ArtDecoTheme.accent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                infoCards[i].description,
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  color: ArtDecoTheme.foreground,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
