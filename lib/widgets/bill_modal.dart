import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../services/api_service.dart';
import '../screens/bill_screen.dart';

Future<bool?> showBillModal(
  BuildContext context, {
  required ApiService apiService,
  required int saleId,
  required BusinessSettings businessSettings,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFFFFBEB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: BillScreen(
        apiService: apiService,
        saleId: saleId,
        businessSettings: businessSettings,
        embedded: true,
      ),
    ),
  );
}
