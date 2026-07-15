import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/app_locale.dart';
import 'l10n/locale_scope.dart';
import 'screens/auth_gate.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  await initializeDateFormatting('si_LK');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  final locale = await loadAppLocale();
  runApp(
    BakeryApp(
      apiService: ApiService(),
      initialLocale: locale,
    ),
  );
}

class BakeryApp extends StatefulWidget {
  const BakeryApp({
    super.key,
    required this.apiService,
    required this.initialLocale,
  });

  final ApiService apiService;
  final AppLocale initialLocale;

  @override
  State<BakeryApp> createState() => _BakeryAppState();
}

class _BakeryAppState extends State<BakeryApp> {
  late final LocaleController _localeController;

  @override
  void initState() {
    super.initState();
    _localeController = LocaleController(widget.initialLocale);
  }

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const amberSeed = Color(0xFFD97706);

    return LocaleScope(
      controller: _localeController,
      child: ListenableBuilder(
        listenable: _localeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Bakery Mobile',
            theme: ThemeData(
              fontFamily: 'NotoSansSinhala',
              colorScheme: ColorScheme.fromSeed(
                seedColor: amberSeed,
                primary: const Color(0xFFB45309),
                surface: Colors.white,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFFFFBEB),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFFFFBEB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFD97706),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 2,
                  ),
                ),
                labelStyle: const TextStyle(color: Color(0xFF57534E)),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            home: AuthGate(apiService: widget.apiService),
          );
        },
      ),
    );
  }
}
