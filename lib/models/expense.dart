class Expense {
  Expense({
    required this.title,
    required this.amountInKurus,
    required this.paidById,
    required this.createdById,
    required this.createdAt,
    required Map<String, int> shares,
  }) : shares = Map<String, int>.unmodifiable(shares);

  final String title;
  final int amountInKurus;
  final String paidById;
  final String createdById;
  final DateTime createdAt;
  final Map<String, int> shares;
}
