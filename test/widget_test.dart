import 'package:flutter_test/flutter_test.dart';

import 'package:bakery_mobile/l10n/app_locale.dart';
import 'package:bakery_mobile/main.dart';
import 'package:bakery_mobile/services/api_service.dart';

void main() {
  testWidgets('App boots to login gate', (WidgetTester tester) async {
    await tester.pumpWidget(
      BakeryApp(
        apiService: ApiService(),
        initialLocale: AppLocale.en,
      ),
    );
    await tester.pump();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
