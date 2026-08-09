import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/db_helper.dart';
import 'theme/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Le confirma a Android (sobre todo en Android 14/15) que la app maneja
  // el color/brillo de sus propias barras de sistema. Sin esto, algunos
  // teléfonos ignoran lo que le mandamos abajo y usan su propio criterio.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Cuando vuelves a la app desde segundo plano, algunos teléfonos
  // (sobre todo Samsung) resetean el color/brillo de la barra de
  // navegación a su valor por defecto. Al volver, se lo volvemos a
  // aplicar a mano para que no se quede en el color equivocado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final themeProvider = context.read<ThemeProvider>();
      final isDark = themeProvider.themeMode == ThemeMode.dark ||
          (themeProvider.themeMode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
      SystemChrome.setSystemUIOverlayStyle(themeProvider.overlayStyleFor(isDark));
    }
  }

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
      // teléfono (abajo) al color claro/oscuro de la app. El AppBar de
      // cada pantalla ya trae su propio systemOverlayStyle (ver
      // theme_provider.dart), esto cubre las pantallas que no tienen AppBar.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: themeProvider.overlayStyleFor(isDark),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainNav(),
    );
  }
}