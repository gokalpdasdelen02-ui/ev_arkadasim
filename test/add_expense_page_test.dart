import 'dart:async';

import 'package:ev_arkadasim/add_expense_page.dart';
import 'package:ev_arkadasim/models/expense.dart';
import 'package:ev_arkadasim/services/balance_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Uses household account IDs for expense shares and balances', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ownerId = 'account-01';
    const memberId = 'account-02';
    final commit = Completer<void>();
    Expense? submitted;
    Expense? expense;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                expense = await Navigator.of(context).push<Expense>(
                  MaterialPageRoute<Expense>(
                    builder: (_) => AddExpensePage(
                      userId: ownerId,
                      members: const {memberId: 'Deniz', ownerId: 'Ekin'},
                      onSave: (value) {
                        submitted = value;
                        return commit.future;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Formu aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Formu aç'));
    await tester.pumpAndSettle();

    final participants = find.byType(CheckboxListTile);
    expect(participants, findsNWidgets(2));
    expect(
      find.descendant(of: participants, matching: find.text('Deniz')),
      findsOneWidget,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Market');
    await tester.enterText(fields.at(1), '12,51');
    await tester.tap(find.text('Bilgileri kontrol et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gideri kaydet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gider kaydediliyor…'), findsOneWidget);
    expect(submitted, isNotNull);
    expect(expense, isNull);

    commit.complete();
    await tester.pumpAndSettle();

    expect(expense, isNotNull);
    final saved = expense!;
    expect(saved, same(submitted));
    expect(saved.createdById, ownerId);
    expect(saved.paidById, ownerId);
    expect(saved.shares, {ownerId: 626, memberId: 625});
    expect(calculateBalances(userId: ownerId, expenses: [saved]), {
      memberId: 625,
    });
    expect(calculateBalances(userId: memberId, expenses: [saved]), {
      ownerId: -625,
    });
  });
}
