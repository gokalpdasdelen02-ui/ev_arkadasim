import '../models/expense.dart';

Map<String, int> calculateBalances({
  required String userId,
  required Iterable<Expense> expenses,
}) {
  final balances = <String, int>{};

  for (final expense in expenses) {
    if (expense.paidById == userId) {
      for (final share in expense.shares.entries) {
        if (share.key == userId) {
          continue;
        }

        balances[share.key] = (balances[share.key] ?? 0) + share.value;
      }
    } else {
      final myShare = expense.shares[userId] ?? 0;

      if (myShare == 0) {
        continue;
      }

      final payerId = expense.paidById;

      balances[payerId] = (balances[payerId] ?? 0) - myShare;
    }
  }

  balances.removeWhere((memberId, amount) => amount == 0);

  return balances;
}
