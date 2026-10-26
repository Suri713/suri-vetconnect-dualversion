import 'package:flutter/material.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/business/pages/business_home.dart';
import 'package:vetconnect/business/pages/create_business.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/donate/pages/donate_page.dart';
import 'package:vetconnect/home_page.dart';
import 'package:vetconnect/jobs/pages/conservation_jobs_page.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  List<Widget> get pages => [
    const HomePage(),
    if (Constants.firebaseHelper.canManageBusiness) const CreateBusiness(),
    const BusinessHome(),
    if (Constants.firebaseHelper.canManageBusiness)
      const ConservationJobsPage(),
    const DonatePage(),
  ];
  int index = 0;
  final Set<int> _visitedPages = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: List.generate(
          pages.length,
          (pageIndex) => _visitedPages.contains(pageIndex)
              ? TickerMode(enabled: index == pageIndex, child: pages[pageIndex])
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: ArtDecoTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Color(0x1813183B),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: ArtDecoTheme.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: ArtDecoTheme.backgroundStart.withAlpha(24),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? ArtDecoTheme.backgroundStart
                    : ArtDecoTheme.onSurfaceMuted,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 23,
                color: states.contains(WidgetState.selected)
                    ? ArtDecoTheme.backgroundStart
                    : ArtDecoTheme.onSurfaceMuted,
              ),
            ),
          ),
          child: NavigationBar(
            height: 72,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() {
              _visitedPages.add(value);
              index = value;
            }),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              if (Constants.firebaseHelper.canManageBusiness)
                const NavigationDestination(
                  icon: Icon(Icons.add_business_outlined),
                  selectedIcon: Icon(Icons.add_business_rounded),
                  label: 'Create',
                ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Explore',
              ),
              if (Constants.firebaseHelper.canManageBusiness)
                const NavigationDestination(
                  icon: Icon(Icons.eco_outlined),
                  selectedIcon: Icon(Icons.eco_rounded),
                  label: 'Careers',
                ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Donations',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
