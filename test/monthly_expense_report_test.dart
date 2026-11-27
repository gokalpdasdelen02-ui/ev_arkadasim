import 'package:ev_arkadasim/models/expense.dart';
import 'package:ev_arkadasim/services/monthly_expense_report.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense(
  String title,
  DateTime date, {
  int amount = 12001,
  String payer = 'ada',
  List<String> participants = const ['ada', 'deniz'],
}) {
  return Expense.equalSplit(
    title: title,
    amountInKurus: amount,
    paidById: payer,
    createdById: payer,
    createdAt: date,
    participantIds: participants,
  );
}

void main() {
  test('Monthly report includes only the selected month and year', () {
    final report = buildMonthlyExpenseReport(
      month: DateTime(2026, 12),
      expenses: [
        _expense('Önceki ay', DateTime(2026, 11, 30, 23, 59)),
        _expense('Önceki yıl', DateTime(2025, 12, 1)),
        _expense(
          'Temizlik',
          DateTime(2026, 12, 1),
          amount: 3000,
          payer: 'ekin',
          participants: ['deniz'],
        ),
        _expense('Market', DateTime(2026, 12, 31, 23, 59)),
        _expense('Sonraki ay', DateTime(2027)),
      ],
    );

    expect(report.expenses.map((expense) => expense.title), ['Market', 'Temizlik']);
    expect(report.totalInKurus, 15001);
    expect(report.paidByMember, {'ada': 12001, 'ekin': 3000});
    expect(report.sharesByMember, {'ada': 6001, 'deniz': 9000});
  });

  test('An empty month does not carry over previous spending', () {
    final report = buildMonthlyExpenseReport(
      month: DateTime(2027),
      expenses: [_expense('Market', DateTime(2026, 12, 31, 12))],
    );

    expect(report.expenses, isEmpty);
    expect(report.totalInKurus, 0);
    expect(report.paidByMember, isEmpty);
    expect(report.sharesByMember, isEmpty);
  });
}
