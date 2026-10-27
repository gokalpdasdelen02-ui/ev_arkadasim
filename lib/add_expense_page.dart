import 'package:flutter/material.dart';

import 'models/expense.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  static const _members = {'me': 'Sen', 'ayse': 'Ayşe', 'zeynep': 'Zeynep'};

  String _paidById = 'me';
  final Set<String> _participantIds = {'me', 'ayse', 'zeynep'};
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int? _parseAmountInKurus(String input) {
    final text = input.trim();

    if (!RegExp(r'^[0-9]+([,.][0-9]{1,2})?$').hasMatch(text)) {
      return null;
    }

    final parts = text.replaceAll(',', '.').split('.');
    final lira = parts[0];
    final kurus = parts.length == 2 ? parts[1].padRight(2, '0') : '00';

    return int.tryParse('$lira$kurus');
  }

  Map<String, int> _splitEqually(int amountInKurus) {
    final participantIds = _participantIds.toList()..sort();

    if (participantIds.isEmpty) {
      throw StateError('Pay hesaplamak için katılımcı gerekli.');
    }

    final baseShare = amountInKurus ~/ participantIds.length;
    final remainingKurus = amountInKurus % participantIds.length;

    final shares = <String, int>{};

    for (var index = 0; index < participantIds.length; index++) {
      final extraKurus = index < remainingKurus ? 1 : 0;

      shares[participantIds[index]] = baseShare + extraKurus;
    }

    return shares;
  }

  String _formatMoney(int amountInKurus) {
    final lira = amountInKurus ~/ 100;
    final kurus = (amountInKurus % 100).toString().padLeft(2, '0');

    return '$lira,$kurus TL';
  }

  Future<void> _checkExpense() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final amountInKurus = _parseAmountInKurus(_amountController.text);

    String message;

    if (name.isEmpty) {
      message = 'Lütfen gider adını gir.';
    } else if (amountInKurus == null) {
      message = 'Geçerli bir tutar gir. Örneğin: 125,50';
    } else if (amountInKurus <= 0) {
      message = 'Tutar sıfırdan büyük olmalı.';
    } else if (_participantIds.isEmpty) {
      message = 'En az bir katılımcı seç.';
    } else {
      final shares = _splitEqually(amountInKurus);
      final expense = Expense(
        title: name,
        amountInKurus: amountInKurus,
        paidById: _paidById,
        createdById: 'me',
        createdAt: DateTime.now(),
        shares: shares,
      );

      final shareLines = expense.shares.entries
          .map((entry) {
            final memberName = _members[entry.key]!;
            final amountText = _formatMoney(entry.value);

            return '$memberName: $amountText';
          })
          .join('\n');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Gider payları'),
            content: SingleChildScrollView(
              child: Text(
                '${expense.title}\n'
                'Toplam: ${_formatMoney(expense.amountInKurus)}\n'
                'Ödeyen: ${_members[expense.paidById]}\n\n'
                '$shareLines\n\n'
                'Payları kontrol edip gideri listeye ekleyebilirsin.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Düzenlemeye dön'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Listeye ekle'),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }

      if (shouldAdd == true) {
        Navigator.of(context).pop(expense);
      }
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gider ekle')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Harcama bilgileri',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Ortak harcamanın adını ve toplam tutarını gir.'),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
            },
            decoration: const InputDecoration(
              labelText: 'Gider adı',
              hintText: 'Örneğin: Market',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
            },
            decoration: const InputDecoration(
              labelText: 'Toplam tutar',
              hintText: 'Örneğin: 125,50',
              suffixText: 'TL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _paidById,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kim ödedi?',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: _members.entries.map((member) {
              return DropdownMenuItem<String>(
                value: member.key,
                child: Text(member.value),
              );
            }).toList(),
            onChanged: (selectedId) {
              if (selectedId == null) {
                return;
              }

              setState(() {
                _paidById = selectedId;
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Kimler arasında bölüşülsün?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final member in _members.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(member.value),
              value: _participantIds.contains(member.key),
              onChanged: (checked) {
                if (checked == null) {
                  return;
                }

                setState(() {
                  if (checked) {
                    _participantIds.add(member.key);
                  } else {
                    _participantIds.remove(member.key);
                  }
                });
              },
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _checkExpense,
            icon: const Icon(Icons.check),
            label: const Text('Bilgileri kontrol et'),
          ),
        ],
      ),
    );
  }
}
