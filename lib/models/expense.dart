class Expense {
  Expense({
    required this.title,
    required this.amountInKurus,
    required this.paidById,
    required this.createdById,
    required this.createdAt,
    required Map<String, int> shares,
  }) : shares = Map<String, int>.unmodifiable(shares);

  static const maxTitleLength = 80;
  static const maxAmountInKurus = 100000000;
  static const maxParticipants = 8;

  factory Expense.equalSplit({
    required String title,
    required int amountInKurus,
    required String paidById,
    required String createdById,
    required DateTime createdAt,
    required Iterable<String> participantIds,
  }) {
    final ids = participantIds.toList()..sort();
    if (ids.isEmpty) {
      throw ArgumentError('Pay hesaplamak için katılımcı gerekli.');
    }

    final baseShare = amountInKurus ~/ ids.length;
    final remainder = amountInKurus % ids.length;

    return Expense(
      title: title,
      amountInKurus: amountInKurus,
      paidById: paidById,
      createdById: createdById,
      createdAt: createdAt,
      shares: {
        for (var i = 0; i < ids.length; i++)
          ids[i]: baseShare + (i < remainder ? 1 : 0),
      },
    );
  }

  final String title;
  final int amountInKurus;
  final String paidById;
  final String createdById;
  final DateTime createdAt;
  final Map<String, int> shares;
}
