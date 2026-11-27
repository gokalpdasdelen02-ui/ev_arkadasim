import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment.dart';

class PaymentService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _payments(String householdId) {
    return _db.collection('households').doc(householdId).collection('payments');
  }

  Stream<List<Payment>> watchPayments(String householdId, String userId) {
    return _payments(householdId)
        .where(
          Filter.or(
            Filter('debtorId', isEqualTo: userId),
            Filter('creditorId', isEqualTo: userId),
          ),
        )
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final payments = [
            for (final doc in snapshot.docs)
              if (!doc.metadata.hasPendingWrites) _decode(doc.id, doc.data()),
          ];
          payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return payments;
        });
  }

  Future<void> reportPayment({
    required String householdId,
    required String debtorId,
    required String creditorId,
    required int amountInKurus,
  }) {
    final doc = _payments(householdId).doc();

    return _db.runTransaction<void>((transaction) async {
      transaction.set(doc, {
        'debtorId': debtorId,
        'creditorId': creditorId,
        'amountInKurus': amountInKurus,
        'status': PaymentStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> resolvePayment({
    required String householdId,
    required String paymentId,
    required PaymentStatus status,
  }) async {
    if (status == PaymentStatus.pending) {
      throw ArgumentError.value(status, 'status', 'Bir karar gerekli.');
    }
    final doc = _payments(householdId).doc(paymentId);

    await _db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(doc);
      final current = snapshot.data()?['status'];
      if (current == status.name) return;
      if (current != PaymentStatus.pending.name) {
        throw StateError('Bu bildirim artık beklemede değil.');
      }

      transaction.update(doc, {
        'status': status.name,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Payment _decode(String id, Map<String, dynamic> data) {
    return Payment(
      id: id,
      debtorId: data['debtorId'] as String,
      creditorId: data['creditorId'] as String,
      amountInKurus: data['amountInKurus'] as int,
      status: PaymentStatus.values.byName(data['status'] as String),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
