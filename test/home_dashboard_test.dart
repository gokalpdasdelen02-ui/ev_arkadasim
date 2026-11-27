import 'package:ev_arkadasim/app_theme.dart';
import 'package:ev_arkadasim/home_dashboard.dart';
import 'package:ev_arkadasim/models/expense.dart';
import 'package:ev_arkadasim/models/household.dart';
import 'package:ev_arkadasim/models/payment.dart';
import 'package:ev_arkadasim/payment_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _members = {'me': 'Gökalp', 'deniz': 'Deniz', 'ece': 'Ece'};

Payment _incoming(PaymentStatus status) => Payment(
  id: 'incoming',
  debtorId: 'ece',
  creditorId: 'me',
  amountInKurus: 3000,
  status: status,
  createdAt: DateTime.now(),
);

List<Expense> _expenses() => [
  Expense.equalSplit(
    title: 'Market',
    amountInKurus: 12000,
    paidById: 'deniz',
    createdById: 'deniz',
    createdAt: DateTime.now(),
    participantIds: ['deniz', 'me'],
  ),
  Expense.equalSplit(
    title: 'İnternet',
    amountInKurus: 15000,
    paidById: 'me',
    createdById: 'me',
    createdAt: DateTime.now(),
    participantIds: ['ece', 'me'],
  ),
];

Future<void> _mount(
  WidgetTester tester, {
  required ValueNotifier<List<Payment>> payments,
  bool owner = true,
  Brightness brightness = Brightness.light,
  Future<bool> Function(String, String, int)? onReport,
  Future<void> Function(Payment, PaymentStatus)? onDecide,
}) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final expenses = _expenses();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness),
      home: ValueListenableBuilder(
        valueListenable: payments,
        builder: (_, value, _) => HomeDashboard(
          household: Household(id: 'house', name: 'Bizim Ev', isOwner: owner),
          userId: 'me',
          names: const AsyncSnapshot.withData(ConnectionState.active, _members),
          expenses: AsyncSnapshot.withData(ConnectionState.active, expenses),
          payments: AsyncSnapshot.withData(ConnectionState.active, value),
          signingOut: false,
          savingName: false,
          creatingInvite: false,
          savingPayment: false,
          onRetryMembers: () {},
          onRetryExpenses: () {},
          onRetryPayments: () {},
          onEditName: (_) async {},
          onInvite: () {},
          onSignOut: () {},
          onAddExpense: (_) async {},
          onReportPayment: onReport ?? (_, _, _) async => false,
          onDecidePayment: onDecide ?? (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('Overview, monthly report, settings and incoming approvals', (
    tester,
  ) async {
    final payments = ValueNotifier([_incoming(PaymentStatus.pending)]);
    addTearDown(payments.dispose);
    await _mount(
      tester,
      payments: payments,
      onDecide: (payment, status) async {
        expect(payment.id, 'incoming');
        expect(status, PaymentStatus.approved);
        payments.value = [_incoming(status)];
      },
    );

    expect(find.text('Borçlarım'), findsOneWidget);
    expect(find.text('Alacaklarım'), findsOneWidget);
    expect(find.text('Gider ekle'), findsOneWidget);
    final pending = find.text('1 ödeme onayını bekliyor');
    expect(pending, findsOneWidget);

    await tester.tap(pending);
    await tester.pumpAndSettle();
    expect(find.text('Gider ekle'), findsNothing);
    await tester.tap(find.text('Ödemeyi aldım'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Onaylandı'), findsOneWidget);

    await tester.tap(_tab('Özet'));
    await tester.pumpAndSettle();
    expect(pending, findsNothing);
    expect(find.text('45,00 TL'), findsWidgets);
    expect(find.text('75,00 TL'), findsNothing);

    await tester.tap(_tab('Giderler'));
    await tester.pumpAndSettle();
    expect(find.text('Market'), findsOneWidget);
    await tester.tap(find.text('Aylık gider tablosu'));
    await tester.pumpAndSettle();
    expect(find.text('Toplam harcama'), findsOneWidget);
    expect(find.text('270,00 TL'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ev ayarları'));
    await tester.pumpAndSettle();
    expect(find.text('Davet kodu oluştur'), findsOneWidget);
    expect(find.text('Görünen ad'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
    await tester.tap(find.text('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Aylık gider tablosu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports a validated payment and opens the payments tab', (
    tester,
  ) async {
    final payments = ValueNotifier(<Payment>[]);
    addTearDown(payments.dispose);
    await _mount(
      tester,
      payments: payments,
      owner: false,
      brightness: Brightness.dark,
      onReport: (id, name, debt) async {
        final amount = await requestPaymentAmount(
          context: tester.element(find.byType(HomeDashboard)),
          creditorName: name,
          maxAmountInKurus: debt,
        );
        if (amount == null) return false;
        expect(amount, 3050);
        payments.value = [
          Payment(
            id: 'outgoing',
            debtorId: 'me',
            creditorId: id,
            amountInKurus: amount,
            status: PaymentStatus.pending,
            createdAt: DateTime.now(),
          ),
        ];
        return true;
      },
    );

    await tester.ensureVisible(find.text('Ödeme bildir'));
    await tester.tap(find.text('Ödeme bildir'));
    await tester.pumpAndSettle();
    expect(find.text('Alacaklı: Deniz'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '60,01');
    await tester.tap(find.text('Bildir'));
    await tester.pumpAndSettle();
    expect(find.text('En fazla 60,00 TL bildirebilirsin.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '30,50');
    await tester.tap(find.text('Bildir'));
    await tester.pumpAndSettle();
    expect(find.text('Deniz · 30,50 TL'), findsOneWidget);
    expect(find.textContaining('Alacaklının onayı bekleniyor'), findsOneWidget);

    await tester.tap(find.text('Ev ayarları'));
    await tester.pumpAndSettle();
    expect(find.text('Davet kodu oluştur'), findsNothing);
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
