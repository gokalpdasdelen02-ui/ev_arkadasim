import '../models/expense.dart';

class MonthlyExpenseReport {
  MonthlyExpenseReport._({
    required List<Expense> expenses,
    required this.totalInKurus,
    required Map<String, int> paidByMember,
    required Map<String, int> sharesByMember,
  }) : expenses = List.unmodifiable(expenses),
       paidByMember = Map.unmodifiable(paidByMember),
       sharesByMember = Map.unmodifiable(sharesByMember);

  final List<Expense> expenses;
  final int totalInKurus;
  final Map<String, int> paidByMember;
  final Map<String, int> sharesByMember;
}

MonthlyExpenseReport buildMonthlyExpenseReport({
  required DateTime month,
  required Iterable<Expense> expenses,
}) {
  final monthly = <Expense>[];
  final paidByMember = <String, int>{};
  final sharesByMember = <String, int>{};
  var total = 0;

  for (final expense in expenses) {
    final date = expense.createdAt.toLocal();
    if (date.year != month.year || date.month != month.month) continue;

    monthly.add(expense);
    total += expense.amountInKurus;
    paidByMember[expense.paidById] =
        (paidByMember[expense.paidById] ?? 0) + expense.amountInKurus;

    for (final share in expense.shares.entries) {
      sharesByMember[share.key] = (sharesByMember[share.key] ?? 0) + share.value;
    }
  }

  monthly.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return MonthlyExpenseReport._(
    expenses: monthly,
    totalInKurus: total,
    paidByMember: paidByMember,
    sharesByMember: sharesByMember,
  );
}
