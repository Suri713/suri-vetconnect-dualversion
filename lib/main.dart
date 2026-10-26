import 'package:firebase_auth/firebase_auth.dart';
import 'package:vetconnect/services/nearby_business_search.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:vetconnect/registration/pathway_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vetconnect/business/pages/business_ai_search.dart';
import 'package:vetconnect/business/pages/business_home.dart';
import 'package:vetconnect/business/pages/business_search.dart';
import 'package:vetconnect/business/pages/create_business.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/firebase_options.dart';
import 'package:vetconnect/registration/login.dart';
import 'package:vetconnect/registration/register.dart';
import 'package:vetconnect/route_page.dart';
import 'package:vetconnect/settings/settings.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

abstract class AppRoutes {
  static const String choosePathway = '/choose-pathway';
  static const String register = '/register';
  static const String login = '/login';
  static const String route = '/route';
  static const String createBusiness = '/create-business';
  static const String businessHome = '/business-home';
  static const String businessSearch = '/business-search';
  static const String businessAiSearch = '/business-ai-search';
  static const String settings = '/settings';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool _isSignedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  bool _hasAnonymousSession() {
    try {
      return Constants.firebaseHelper.anonymous;
    } catch (_) {
      return false;
    }
  }

  Route<dynamic> _guardedRoute(Widget page, {bool veteranOnly = false}) {
    if (_isSignedIn() || _hasAnonymousSession()) {
      if (Constants.firebaseHelper.pathway == null) {
        return MaterialPageRoute(
          builder: (_) => const PathwayPage(forExistingAccount: true),
        );
      }
      if (veteranOnly && !Constants.firebaseHelper.canManageBusiness) {
        return MaterialPageRoute(builder: (_) => const RoutePage());
      }
      return MaterialPageRoute(builder: (_) => page);
    }

    return MaterialPageRoute(builder: (_) => const LoginPage());
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.choosePathway:
        return MaterialPageRoute(
          builder: (_) =>
              PathwayPage(forExistingAccount: settings.arguments == true),
        );
      case AppRoutes.register:
        final pathway = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => pathway is AccountPathway
              ? RegisterPage(pathway: pathway)
              : const PathwayPage(),
        );
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => LoginPage());
      case AppRoutes.route:
        return _guardedRoute(const RoutePage());
      case AppRoutes.createBusiness:
        return _guardedRoute(const CreateBusiness(), veteranOnly: true);
      case AppRoutes.businessHome:
        return _guardedRoute(const BusinessHome());
      case AppRoutes.businessSearch:
        return _guardedRoute(const BusinessSearch());
      case AppRoutes.businessAiSearch:
        return _guardedRoute(
          BusinessAiSearch(
            initialArea: settings.arguments is AiSearchArea
                ? settings.arguments as AiSearchArea
                : null,
          ),
        );
      case AppRoutes.settings:
        return _guardedRoute(const SettingsPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeteranConnect',
      debugShowCheckedModeBanner: false,
      theme: ArtDecoTheme.build(),
      onGenerateRoute: _onGenerateRoute,
      home: const LoginPage(),
    );
  }
}
