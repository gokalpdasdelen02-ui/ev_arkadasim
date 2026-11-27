import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/expense.dart';
import 'money.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({
    super.key,
    required this.userId,
    required this.members,
    required this.onSave,
  });

  final String userId;
  final Map<String, String> members;
  final Future<void> Function(Expense) onSave;

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  late String _paidById;
  late final Set<String> _participantIds;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _paidById = widget.userId;
    _participantIds = widget.members.keys.toSet();
  }

  String _memberLabel(String id) {
    final name = widget.members[id] ?? 'Üye';
    return id == widget.userId ? '$name (sen)' : name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkExpense() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final amountInKurus = parseMoneyInKurus(_amountController.text);

    String message;

    if (name.isEmpty) {
      message = 'Lütfen gider adını gir.';
    } else if (name.length > Expense.maxTitleLength) {
      message =
          'Gider adı en fazla ${Expense.maxTitleLength} karakter olabilir.';
    } else if (amountInKurus == null) {
      message = 'Geçerli bir tutar gir. Örneğin: 125,50';
    } else if (amountInKurus <= 0) {
      message = 'Tutar sıfırdan büyük olmalı.';
    } else if (amountInKurus > Expense.maxAmountInKurus) {
      message = 'Bir gider en fazla 1.000.000 TL olabilir.';
    } else if (_participantIds.isEmpty) {
      message = 'En az bir katılımcı seç.';
    } else if (_participantIds.length > Expense.maxParticipants) {
      message =
          'Bir gider için en fazla ${Expense.maxParticipants} kişi seçebilirsin.';
    } else {
      final expense = Expense.equalSplit(
        title: name,
        amountInKurus: amountInKurus,
        paidById: _paidById,
        createdById: widget.userId,
        createdAt: DateTime.now(),
        participantIds: _participantIds,
      );

      final shareLines = expense.shares.entries
          .map((entry) {
            final memberName = _memberLabel(entry.key);
            final amountText = formatMoney(entry.value);

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
                'Toplam: ${formatMoney(expense.amountInKurus)}\n'
                'Ödeyen: ${_memberLabel(expense.paidById)}\n\n'
                '$shareLines\n\n'
                'Kaydettiğinde gideri ev üyeleri de görebilecek.',
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
                child: const Text('Gideri kaydet'),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }

      if (shouldAdd == true) {
        await _saveExpense(expense);
      }
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveExpense(Expense expense) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await widget.onSave(expense);
    } catch (error) {
      debugPrint('Gider kaydedilemedi: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gider kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
          ),
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(expense);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Expense>(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gider ekle')),
        body: _saving
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Gider kaydediliyor…'),
                  ],
                ),
              )
            : SafeArea(child: _buildForm(context)),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppTheme.pagePadding,
      children: [
        Text(
          'Harcama bilgileri',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Ortak harcamanın adını ve toplam tutarını gir.'),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          maxLength: Expense.maxTitleLength,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
          },
          decoration: const InputDecoration(
            labelText: 'Gider adı',
            hintText: 'Örneğin: Market',
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
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: widget.members.keys.map((id) {
            return DropdownMenuItem<String>(
              value: id,
              child: Text(_memberLabel(id)),
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
        Text(
          'Kimler arasında bölüşülsün?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final id in widget.members.keys)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(_memberLabel(id)),
            value: _participantIds.contains(id),
            onChanged: (checked) {
              if (checked == null) {
                return;
              }

              setState(() {
                if (checked) {
                  _participantIds.add(id);
                } else {
                  _participantIds.remove(id);
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
    );
  }
}
