enum PaymentStatus { pending, approved, rejected }

class Payment {
  const Payment({
    required this.id,
    required this.debtorId,
    required this.creditorId,
    required this.amountInKurus,
    required this.status,
    required this.createdAt,
  });

  static const maxAmountInKurus = 100000000;

  final String id;
  final String debtorId;
  final String creditorId;
  final int amountInKurus;
  final PaymentStatus status;
  final DateTime createdAt;
}
