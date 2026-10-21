import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/database.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.initFactory();
  final state = AppState();
  await state.loadInitialSettings();
  runApp(ChangeNotifierProvider.value(value: state, child: const MedicalShopApp()));
  state.startBackgroundServices();
}

class MedicalShopApp extends StatelessWidget {
  const MedicalShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Oscar Pharma',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
