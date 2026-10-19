import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/database.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.initFactory();
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const MedicalShopApp()));
}

class MedicalShopApp extends StatelessWidget {
  const MedicalShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oscar Pharma',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.light,
      home: const Shell(),
    );
  }
}
