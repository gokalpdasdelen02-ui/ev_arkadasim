import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household.dart';

class HouseholdService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _membership(String uid) {
    return _db.collection('memberships').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _members(String householdId) {
    return _db.collection('households').doc(householdId).collection('members');
  }

  Stream<Map<String, String>> watchMemberNames(String householdId) {
    return _members(householdId).snapshots().map((snapshot) {
      final names = <String, String>{};
      for (final member in snapshot.docs) {
        final name = member.data()['displayName'];
        if (name is String && name.trim().isNotEmpty) {
          names[member.id] = name;
        }
      }

      return Map<String, String>.unmodifiable(names);
    });
  }

  Future<void> saveMemberName({
    required String householdId,
    required String uid,
    required String name,
  }) {
    return _members(householdId).doc(uid).set({'displayName': name.trim()});
  }

  Future<Household?> getHousehold(String uid) async {
    final membership = await _membership(uid).get();
    if (!membership.exists) return null;

    final id = membership.data()!['householdId'] as String;
    final snapshot = await _db.collection('households').doc(id).get();
    final name = snapshot.data()?['name'];

    if (name is! String) {
      throw StateError('Üyeliğe bağlı ev bulunamadı.');
    }

    return Household(
      id: id,
      name: name,
      isOwner: membership.data()?['role'] == 'owner',
    );
  }

  Future<Household> createHousehold({
    required String uid,
    required String name,
  }) async {
    final household = _db.collection('households').doc();
    final batch = _db.batch();

    batch.set(household, {
      'name': name,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_membership(uid), {
      'householdId': household.id,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return Household(id: household.id, name: name, isOwner: true);
  }

  Future<String> createInviteCode(String householdId) async {
    final random = Random.secure();
    final code = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    await _db.collection('householdInvites').doc(code).set({
      'householdId': householdId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  Future<bool> joinWithInvite({
    required String uid,
    required String input,
  }) async {
    final code = input.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) return false;

    final invite = _db.collection('householdInvites').doc(code);
    final membership = _membership(uid);

    return _db.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(membership);
      if (existing.exists) return false;

      final data = (await transaction.get(invite)).data();
      if (data == null) return false;

      transaction.set(membership, {
        'householdId': data['householdId'],
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'inviteCode': code,
      });
      transaction.delete(invite);

      return true;
    });
  }
}
