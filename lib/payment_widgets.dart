import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/payment.dart';
import 'money.dart';

Future<int?> requestPaymentAmount({
  required BuildContext context,
  required String creditorName,
  required int maxAmountInKurus,
}) => Navigator.of(context).push<int>(
  MaterialPageRoute<int>(
    builder: (_) => _PaymentAmountPage(
      creditorName: creditorName,
      maxAmountInKurus: maxAmountInKurus,
    ),
  ),
);

class _PaymentAmountPage extends StatefulWidget {
  const _PaymentAmountPage({
    required this.creditorName,
    required this.maxAmountInKurus,
  });

  final String creditorName;
  final int maxAmountInKurus;

  @override
  State<_PaymentAmountPage> createState() => _PaymentAmountPageState();
}

class _PaymentAmountPageState extends State<_PaymentAmountPage> {
  final _formKey = GlobalKey<FormState>();
  late int _amount;

  void _submit() {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    Navigator.of(context).pop(_amount);
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme bildir')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppTheme.pagePadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text('Alacaklı: ${widget.creditorName}', style: type.titleLarge),
              const SizedBox(height: 8),
              const Text('Parayı gönderdiysen ödediğin tutarı gir.'),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: formatAmount(widget.maxAmountInKurus),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ödenen tutar (TL)',
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                validator: (value) {
                  final parsed = parseMoneyInKurus(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Geçerli bir tutar gir.';
                  }
                  if (parsed > widget.maxAmountInKurus) {
                    return 'En fazla ${formatMoney(widget.maxAmountInKurus)} bildirebilirsin.';
                  }
                  return null;
                },
                onSaved: (value) => _amount = parseMoneyInKurus(value!)!,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Bildir')),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.userId,
    required this.members,
    required this.payments,
    required this.busy,
    required this.onDecision,
  });

  final String userId;
  final Map<String, String> members;
  final List<Payment> payments;
  final bool busy;
  final Future<void> Function(Payment, PaymentStatus) onDecision;

  @override
  Widget build(BuildContext context) {
    final visible = [
      ...payments.where((item) => item.status == PaymentStatus.pending),
      ...payments.where((item) => item.status != PaymentStatus.pending).take(5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Henüz ödeme bildirimi yok.'),
            ),
          ),
        for (final payment in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPayment(context, payment),
          ),
      ],
    );
  }

  Widget _buildPayment(BuildContext context, Payment payment) {
    final incoming = payment.creditorId == userId;
    final otherId = incoming ? payment.debtorId : payment.creditorId;
    final other = members[otherId] ?? 'Üye';
    final status = switch (payment.status) {
      PaymentStatus.pending =>
        incoming ? 'Onayını bekliyor' : 'Alacaklının onayı bekleniyor',
      PaymentStatus.approved => 'Onaylandı',
      PaymentStatus.rejected => 'Reddedildi',
    };

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ListTile(
            leading: Icon(
              payment.status == PaymentStatus.pending
                  ? Icons.schedule
                  : incoming
                  ? Icons.call_received
                  : Icons.call_made,
              color: payment.status == PaymentStatus.pending
                  ? AppTheme.attention(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              '$other · ${formatMoney(payment.amountInKurus)}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontFeatures: AppTheme.tabularFigures),
            ),
            subtitle: Text(
              '${incoming ? 'Gelen ödeme' : 'Giden ödeme'} · $status',
            ),
          ),
          if (incoming && payment.status == PaymentStatus.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => onDecision(payment, PaymentStatus.rejected),
                    child: const Text('Reddet'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => onDecision(payment, PaymentStatus.approved),
                    child: const Text('Ödemeyi aldım'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
