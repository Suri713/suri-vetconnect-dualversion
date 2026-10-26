import 'package:flutter/material.dart';
import 'package:vetconnect/services/business_recommendations.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';

class BusinessInterestsSheet extends StatefulWidget {
  final RecommendationProfile profile;
  const BusinessInterestsSheet({super.key, required this.profile});
  @override
  State<BusinessInterestsSheet> createState() => _BusinessInterestsSheetState();
}

class _BusinessInterestsSheetState extends State<BusinessInterestsSheet> {
  late final Set<String> _selected = widget.profile.interests.toSet();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: ArtDecoTheme.backgroundStart,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your interests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ArtDecoTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose up to 3. Suggestions also use the map area, your searches, and businesses you open.',
                style: TextStyle(color: ArtDecoTheme.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: businessInterests.keys
                    .map(
                      (interest) => FilterChip(
                        label: Text(interest),
                        selected: _selected.contains(interest),
                        labelStyle: const TextStyle(
                          color: ArtDecoTheme.onSurface,
                        ),
                        backgroundColor: ArtDecoTheme.fieldFill,
                        selectedColor: ArtDecoTheme.accent.withAlpha(80),
                        onSelected:
                            !_selected.contains(interest) &&
                                _selected.length >= 3
                            ? null
                            : (selected) => setState(() {
                                if (selected) {
                                  _selected.add(interest);
                                } else {
                                  _selected.remove(interest);
                                }
                              }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preferences and browsing history stay on this device for your account.',
                style: TextStyle(
                  color: ArtDecoTheme.onSurfaceMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await widget.profile.setInterests(_selected);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save interests'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.profile.clearHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Browsing history cleared')),
                    );
                  }
                },
                child: const Text('Clear browsing history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
