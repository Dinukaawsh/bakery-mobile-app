import 'package:flutter_test/flutter_test.dart';

import 'package:bakery_mobile/main.dart';
import 'package:bakery_mobile/services/api_service.dart';

void main() {
  testWidgets('App boots to login gate', (WidgetTester tester) async {
    await tester.pumpWidget(BakeryApp(apiService: ApiService()));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
