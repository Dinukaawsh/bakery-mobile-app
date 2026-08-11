class DriverExpense {
  final int id;
  final int deliveryGuyId;
  final String deliveryGuyName;
  final String expenseDate;
  final String reason;
  final String amount;
  final String? attachmentUrl;
  final int? salaryPaymentId;
  final bool paid;
  final DateTime? createdAt;

  const DriverExpense({
    required this.id,
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.expenseDate,
    required this.reason,
    required this.amount,
    this.attachmentUrl,
    this.salaryPaymentId,
    required this.paid,
    this.createdAt,
  });

  factory DriverExpense.fromJson(Map<String, dynamic> json) {
    return DriverExpense(
      id: json['id'] as int,
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String? ?? '',
      expenseDate: json['expenseDate'] as String,
      reason: json['reason'] as String,
      amount: json['amount']?.toString() ?? '0',
      attachmentUrl: json['attachmentUrl'] as String?,
      salaryPaymentId: json['salaryPaymentId'] as int?,
      paid: json['paid'] as bool? ?? json['salaryPaymentId'] != null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class SalaryPayment {
  final int id;
  final int deliveryGuyId;
  final String deliveryGuyName;
  final String paidByName;
  final String paymentDate;
  final String salaryAmount;
  final String expensesAmount;
  final String totalPaid;
  final String? notes;
  final List<DriverExpense> expenses;

  const SalaryPayment({
    required this.id,
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.paidByName,
    required this.paymentDate,
    required this.salaryAmount,
    required this.expensesAmount,
    required this.totalPaid,
    this.notes,
    this.expenses = const [],
  });

  factory SalaryPayment.fromJson(Map<String, dynamic> json) {
    return SalaryPayment(
      id: json['id'] as int,
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String? ?? '',
      paidByName: json['paidByName'] as String? ?? '',
      paymentDate: json['paymentDate'] as String,
      salaryAmount: json['salaryAmount']?.toString() ?? '0',
      expensesAmount: json['expensesAmount']?.toString() ?? '0',
      totalPaid: json['totalPaid']?.toString() ?? '0',
      notes: json['notes'] as String?,
      expenses: ((json['expenses'] as List?) ?? [])
          .map((item) {
            final map = item as Map<String, dynamic>;
            return DriverExpense(
              id: map['id'] as int,
              deliveryGuyId: json['deliveryGuyId'] as int? ?? 0,
              deliveryGuyName: json['deliveryGuyName'] as String? ?? '',
              expenseDate: map['expenseDate'] as String? ?? '',
              reason: map['reason'] as String? ?? '',
              amount: map['amount']?.toString() ?? '0',
              paid: true,
            );
          })
          .toList(),
    );
  }
}
