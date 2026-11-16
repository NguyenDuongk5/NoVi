import 'package:flutter/material.dart';
import 'core/session.dart';
import 'core/theme_controller.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NoviThemeController.instance.initialize();
  final session = Session();
  await session.initialize();
  runApp(NoviApp(session: session));
}

class NoviApp extends StatelessWidget {
  const NoviApp({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NoviThemeController.instance,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoVi',
      themeMode: NoviThemeController.instance.mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomeShell(session: session),
    ),
  );
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xffe86b9a),
    brightness: brightness,
    surface: dark ? const Color(0xff211d20) : const Color(0xfffffbfd),
  );
  return ThemeData(
    colorScheme: colors,
    brightness: brightness,
    scaffoldBackgroundColor: dark
        ? const Color(0xff171416)
        : const Color(0xfffff8fb),
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff282326) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xff211d20) : Colors.white,
      indicatorColor: dark ? const Color(0xff5b3445) : const Color(0xffffdce8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff2b2629) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(
        dark ? const Color(0xff2b2629) : Colors.white,
      ),
      elevation: const WidgetStatePropertyAll(0),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xff352b30) : const Color(0xffffedf4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xff282326) : Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xff282326) : Colors.white,
      modalBackgroundColor: dark ? const Color(0xff282326) : Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff171416) : const Color(0xfffff8fb),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
