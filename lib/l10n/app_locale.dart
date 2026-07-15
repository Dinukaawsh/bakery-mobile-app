import 'package:shared_preferences/shared_preferences.dart';

enum AppLocale { en, si }

const localeStorageKey = 'bakery_locale';

extension AppLocaleX on AppLocale {
  String get code => this == AppLocale.si ? 'si' : 'en';

  static AppLocale fromCode(String? code) {
    return code == 'si' ? AppLocale.si : AppLocale.en;
  }
}

Future<AppLocale> loadAppLocale() async {
  final prefs = await SharedPreferences.getInstance();
  return AppLocaleX.fromCode(prefs.getString(localeStorageKey));
}

Future<void> saveAppLocale(AppLocale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(localeStorageKey, locale.code);
}
