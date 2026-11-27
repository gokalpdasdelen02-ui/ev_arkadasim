import 'package:flutter/material.dart';

import 'models/payment.dart';
import 'money.dart';

Future<int?> showPaymentAmountDialog({
  required BuildContext context,
  required String creditorName,
  required int maxAmountInKurus,
}) {
  final formKey = GlobalKey<FormState>();
  var amount = maxAmountInKurus;

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Ödeme bildir'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alacaklı: $creditorName'),
            const Text('Parayı gönderdiysen ödediğin tutarı gir.'),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: formatAmount(maxAmountInKurus),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ödenen tutar (TL)'),
              validator: (value) {
                final parsed = parseMoneyInKurus(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Geçerli bir tutar gir.';
                }
                if (parsed > maxAmountInKurus) {
                  return 'En fazla ${formatMoney(maxAmountInKurus)} bildirebilirsin.';
                }
                return null;
              },
              onSaved: (value) => amount = parseMoneyInKurus(value!)!,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final form = formKey.currentState!;
            if (!form.validate()) return;
            form.save();
            Navigator.pop(dialogContext, amount);
          },
          child: const Text('Bildir'),
        ),
      ],
    ),
  );
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
        Text(
          'Ödeme bildirimleri',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty) const Text('Henüz ödeme bildirimi yok.'),
        for (final payment in visible) _buildPayment(payment),
      ],
    );
  }

  Widget _buildPayment(Payment payment) {
    final incoming = payment.creditorId == userId;
    final otherId = incoming ? payment.debtorId : payment.creditorId;
    final other = members[otherId] ?? 'Üye';
    final status = switch (payment.status) {
      PaymentStatus.pending => 'Onay bekliyor',
      PaymentStatus.approved => 'Onaylandı',
      PaymentStatus.rejected => 'Reddedildi',
    };

    return Card(
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ListTile(
            leading: Icon(incoming ? Icons.call_received : Icons.call_made),
            title: Text(formatMoney(payment.amountInKurus)),
            subtitle: Text(
              '${incoming ? 'Ödemeyi bildiren' : 'Alacaklı'}: $other · $status',
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
                  FilledButton.tonal(
                    onPressed: busy
                        ? null
                        : () => onDecision(payment, PaymentStatus.approved),
                    child: const Text('Onayla'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
