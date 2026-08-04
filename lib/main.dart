import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/db_helper.dart';
import 'theme/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper().processMissedDays();
  await DBHelper().cleanupExpired();
  await NotificationService().init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Desarrollo Personal',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      darkTheme: themeProvider.darkTheme,
      theme: themeProvider.lightTheme,
      // Adapta la barra de estado (arriba) y la barra de navegación del
      // teléfono (abajo, la de "< o III") al color claro/oscuro de la app.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF7F9F7);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: bg,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainNav(),
    );
  }
}