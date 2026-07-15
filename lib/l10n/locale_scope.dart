import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import 'strings_en.dart';
import 'strings_si.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._locale);

  AppLocale _locale;

  AppLocale get locale => _locale;

  String t(String key, [Map<String, Object?>? params]) {
    final catalog = _locale == AppLocale.si ? stringsSi : stringsEn;
    var value = catalog[key] ?? stringsEn[key] ?? key;
    if (params != null) {
      params.forEach((name, paramValue) {
        value = value.replaceAll('{$name}', '${paramValue ?? ''}');
      });
    }
    return value;
  }

  Future<void> setLocale(AppLocale next) async {
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
    await saveAppLocale(next);
  }

  Future<void> toggle() async {
    await setLocale(
      _locale == AppLocale.en ? AppLocale.si : AppLocale.en,
    );
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found');
    return scope!.notifier!;
  }

  static String t(
    BuildContext context,
    String key, [
    Map<String, Object?>? params,
  ]) {
    return of(context).t(key, params);
  }
}
