import 'package:ev_arkadasim/models/expense.dart';
import 'package:ev_arkadasim/models/payment.dart';
import 'package:ev_arkadasim/services/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const debtor = 'debtor';
  const creditor = 'creditor';
  final date = DateTime.utc(2026, 11, 27);
  final expense = Expense.equalSplit(
    title: 'Market',
    amountInKurus: 12000,
    paidById: creditor,
    createdById: creditor,
    createdAt: date,
    participantIds: [debtor, creditor],
  );

  Payment payment(String id, int amount, PaymentStatus status) {
    return Payment(
      id: id,
      debtorId: debtor,
      creditorId: creditor,
      amountInKurus: amount,
      status: status,
      createdAt: date,
    );
  }

  void expectBothBalances(List<Payment> payments, int remaining) {
    expect(
      calculateBalances(
        userId: debtor,
        expenses: [expense],
        payments: payments,
      ),
      {if (remaining > 0) creditor: -remaining},
    );
    expect(
      calculateBalances(
        userId: creditor,
        expenses: [expense],
        payments: payments,
      ),
      {if (remaining > 0) debtor: remaining},
    );
  }

  test('Only approved payments reduce both sides of a shared debt', () {
    final pending = payment('first', 2000, PaymentStatus.pending);
    final rejected = payment('second', 900, PaymentStatus.rejected);
    expectBothBalances([pending, rejected], 6000);

    final approved = payment('first', 2000, PaymentStatus.approved);
    expectBothBalances([approved, rejected], 4000);

    final finalPayment = payment('third', 4000, PaymentStatus.approved);
    expectBothBalances([approved, rejected, finalPayment], 0);
  });
}
