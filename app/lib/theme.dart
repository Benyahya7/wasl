import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wasl brand: deep teal + amber cash accent, blue reserved for marketplace.
/// Logo: teal #0C4A4E tile, amber #F2A81D W-route.
/// Type (high-fi prototype): Sora for headings, DM Sans for body,
/// IBM Plex Sans Arabic as fallback so Arabic text renders in-brand.
class WaslTheme {
  static const teal = Color(0xFF0C4A4E);
  static const tealDark = Color(0xFF093A3D);
  static const amber = Color(0xFFF2A81D);
  static const ink = Color(0xFF10201F);
  static const paper = Color(0xFFF7F5F0);
  static const marketplaceBlue = Color(0xFF2563EB);
  static const okGreen = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);

  static TextTheme get _textTheme {
    final base = ThemeData.light().textTheme;
    final body = GoogleFonts.dmSansTextTheme(base);
    final headings = GoogleFonts.soraTextTheme(base);
    return body
        .copyWith(
          displayLarge: headings.displayLarge,
          displayMedium: headings.displayMedium,
          displaySmall: headings.displaySmall,
          headlineLarge: headings.headlineLarge,
          headlineMedium: headings.headlineMedium,
          headlineSmall: headings.headlineSmall,
          titleLarge: headings.titleLarge,
          titleMedium: headings.titleMedium,
          titleSmall: headings.titleSmall,
        )
        .apply(fontFamilyFallback: const ['IBM Plex Sans Arabic']);
  }

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          secondary: amber,
        ),
        textTheme: _textTheme,
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}

/// The Wasl tile logo for app bars. Falls back to nothing (not a red error
/// box) if the asset is ever missing.
class WaslAppBarLogo extends StatelessWidget {
  const WaslAppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/logo/wasl-icon-192.png',
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The Wasl wordmark for the sign-in screen. Falls back to the plain
/// "Wasl" wordmark text if the asset is ever missing.
class WaslWordmark extends StatelessWidget {
  const WaslWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/wasl-wordmark.png',
      height: 84,
      errorBuilder: (_, _, _) => const Text(
        'Wasl',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: WaslTheme.teal,
        ),
      ),
    );
  }
}

/// Error banner with a Retry button — nothing fails silently.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFDECEC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: WaslTheme.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: WaslTheme.danger)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Small status chip with the right colour per status.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
