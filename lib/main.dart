import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ui/main_app.dart';
import 'services/app_state.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'themes/app_theme.dart';
import 'core/constants/constants_loader.dart';
import 'core/constants/constants_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize services
  final storageService = StorageService();
  await storageService.initialize();

  final authService = AuthService();
  final appState = AppState(storageService, authService);

  await appState.initialize();

  // Load constants and LaTeX symbols
  final constantsRepo = ConstantsRepository();
  await constantsRepo.load();
  final latexMap = await ConstantsLoader.loadLatexSymbols();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider.value(value: storageService),
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: constantsRepo),
        Provider.value(value: latexMap),
      ],
      child: const SemiconductorCalculatorApp(),
    ),
  );
}

class SemiconductorCalculatorApp extends StatelessWidget {
  const SemiconductorCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: 'Semiconductor Formula Calculator',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light, // Force light mode
          home: const MainApp(),
        );
      },
    );
  }
}
