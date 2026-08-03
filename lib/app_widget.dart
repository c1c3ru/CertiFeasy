import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CertiFeasy',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111322),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7A78FF),
          secondary: Color(0xFF4A8BFF),
          surface: Color(0xFF16192B),
          // ignore: deprecated_member_use
          background: Color(0xFF111322),
        ),
        // Fonte principal: Plus Jakarta Sans — mais distinta que Inter,
        // mantém legibilidade técnica com personalidade própria.
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        dividerColor: Colors.white10,
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1E2136),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: Color(0xFF1E2136),
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          textStyle: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    );
  }
}
