import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';

class ArtDecoScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final bool polished;

  const ArtDecoScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.polished = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      extendBodyBehindAppBar: polished && appBar != null,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ArtDecoTheme.backgroundStart,
                  ArtDecoTheme.backgroundEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            left: -120,
            top: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x2EF8F6F0), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            right: -140,
            bottom: -180,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x22F8F6F0), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            top: appBar == null,
            child: Padding(
              padding: EdgeInsets.only(
                top: polished && appBar != null
                    ? MediaQuery.paddingOf(context).top +
                          appBar!.preferredSize.height
                    : 0,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
    if (!polished) return scaffold;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          scrolledUnderElevation: 0,
          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
            color: ArtDecoTheme.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        dividerColor: ArtDecoTheme.onSurface.withAlpha(20),
      ),
      child: scaffold,
    );
  }
}

class ArtDecoPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ArtDecoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: ArtDecoTheme.surface,
        border: Border.all(color: const Color(0x33000000), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1A000000), width: 1),
                ),
              ),
            ),
          ),
          const _CornerBracket(alignment: Alignment.topLeft),
          const _CornerBracket(alignment: Alignment.bottomRight),
          Padding(
            padding: padding,
            child: Theme(
              data: theme.copyWith(
                textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    backgroundColor: ArtDecoTheme.backgroundStart,
                    foregroundColor: ArtDecoTheme.accent,
                    disabledBackgroundColor: ArtDecoTheme.fieldFill,
                    disabledForegroundColor: ArtDecoTheme.onSurfaceMuted,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                iconTheme: theme.iconTheme.copyWith(
                  color: ArtDecoTheme.onSurface,
                ),
                inputDecorationTheme:
                    ArtDecoTheme.onSurfaceInputDecorationTheme(),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ArtDecoTheme.onSurfaceOutlineButtonStyle(),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ArtDecoTheme.onSurfaceTextButtonStyle(),
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: ArtDecoTheme.onSurface,
                  selectionColor: ArtDecoTheme.onSurface.withAlpha(60),
                  selectionHandleColor: ArtDecoTheme.onSurface,
                ),
              ),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft rounded white card (no deco corner brackets), used on the
/// newer rounded/pill-styled pages. Applies the same dark-on-white
/// theme override as [ArtDecoPanel] so nested text/inputs/buttons render
/// correctly against the white background.
class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const RoundedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: ArtDecoTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ArtDecoTheme.backgroundEnd.withAlpha(10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1013183B),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              elevation: 0,
              backgroundColor: ArtDecoTheme.backgroundStart,
              foregroundColor: ArtDecoTheme.accent,
              disabledBackgroundColor: ArtDecoTheme.fieldFill,
              disabledForegroundColor: ArtDecoTheme.onSurfaceMuted,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          iconTheme: theme.iconTheme.copyWith(color: ArtDecoTheme.onSurface),
          inputDecorationTheme: ArtDecoTheme.onSurfaceInputDecorationTheme(),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ArtDecoTheme.onSurfaceOutlineButtonStyle(),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ArtDecoTheme.onSurfaceTextButtonStyle(),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: ArtDecoTheme.onSurface,
            selectionColor: ArtDecoTheme.onSurface.withAlpha(60),
            selectionHandleColor: ArtDecoTheme.onSurface,
          ),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// A circular outlined icon badge, matching the login/register/home
/// header treatment.
class RoundedIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;

  const RoundedIconBadge({
    super.key,
    required this.icon,
    this.size = 84,
    this.iconSize = 34,
    this.color = ArtDecoTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class ArtDecoTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ArtDecoTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineColor = (IconTheme.of(context).color ?? ArtDecoTheme.accent)
        .withAlpha(140);

    return Column(
      children: [
        Container(
          width: 72,
          height: 1,
          color: lineColor,
          margin: const EdgeInsets.only(bottom: 12),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(fontSize: 24),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        Container(
          width: 72,
          height: 1,
          color: lineColor,
          margin: const EdgeInsets.only(top: 12),
        ),
      ],
    );
  }
}

class ArtDecoDiamondIcon extends StatelessWidget {
  final IconData icon;

  const ArtDecoDiamondIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? ArtDecoTheme.accent;

    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          color: color.withAlpha(18),
        ),
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final Alignment alignment;

  const _CornerBracket({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final bool top = alignment == Alignment.topLeft;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: top
                    ? const BorderSide(color: ArtDecoTheme.onSurface, width: 2)
                    : BorderSide.none,
                left: top
                    ? const BorderSide(color: ArtDecoTheme.onSurface, width: 2)
                    : BorderSide.none,
                right: !top
                    ? const BorderSide(color: ArtDecoTheme.onSurface, width: 2)
                    : BorderSide.none,
                bottom: !top
                    ? const BorderSide(color: ArtDecoTheme.onSurface, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared page introduction, kept separate from authentication screens.
class PageIntro extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;
  const PageIntro({
    super.key,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || eyebrow != null) ...[
            Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ArtDecoTheme.accent.withAlpha(22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ArtDecoTheme.accent.withAlpha(45),
                      ),
                    ),
                    child: Icon(icon, size: 20, color: ArtDecoTheme.accent),
                  ),
                if (eyebrow != null) ...[
                  if (icon != null) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      eyebrow!.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(letterSpacing: 1.8),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 28, height: 1.25),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }
}
