import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

class ExpenseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _expenses(String householdId) {
    return _db.collection('households').doc(householdId).collection('expenses');
  }

  Stream<List<Expense>> watchExpenses(String householdId) {
    return _expenses(householdId)
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              if (!doc.metadata.hasPendingWrites) _decode(doc.data()),
          ],
        );
  }

  Future<void> addExpense(String householdId, Expense expense) {
    final doc = _expenses(householdId).doc();

    return _db.runTransaction<void>((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) return;

      transaction.set(doc, {
        'title': expense.title,
        'amountInKurus': expense.amountInKurus,
        'paidById': expense.paidById,
        'createdById': expense.createdById,
        'participantIds': expense.shares.keys.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Expense _decode(Map<String, dynamic> data) {
    return Expense.equalSplit(
      title: data['title'] as String,
      amountInKurus: data['amountInKurus'] as int,
      paidById: data['paidById'] as String,
      createdById: data['createdById'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      participantIds: (data['participantIds'] as List<Object?>).cast<String>(),
    );
  }
}
