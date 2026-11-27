import 'package:flutter/material.dart';

import 'models/expense.dart';
import 'money.dart';
import 'services/monthly_expense_report.dart';

class MonthlyExpensesPage extends StatefulWidget {
  const MonthlyExpensesPage({
    super.key,
    required this.expenses,
    required this.members,
  });

  final List<Expense> expenses;
  final Map<String, String> members;

  @override
  State<MonthlyExpensesPage> createState() => _MonthlyExpensesPageState();
}

class _MonthlyExpensesPageState extends State<MonthlyExpensesPage> {
  static const _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  DateTime _month = DateTime.now();

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
    });
  }

  String _memberName(String id) => widget.members[id] ?? 'Üye';

  String _dateLabel(DateTime timestamp) {
    final date = timestamp.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final isPastMonth = DateTime(
      _month.year,
      _month.month,
    ).isBefore(currentMonth);
    final report = buildMonthlyExpenseReport(
      month: _month,
      expenses: widget.expenses,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Aylık gider tablosu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Önceki ay',
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki ay',
                  onPressed: isPastMonth ? () => _moveMonth(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Toplam harcama'),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(report.totalInKurus),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${report.expenses.length} gider · Kayıt tarihine göre'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (report.expenses.isEmpty)
              const Center(child: Text('Bu ay için kayıtlı gider yok.'))
            else ...[
              Text('Üyelere göre', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Ödediği tutar ve giderlerden kendisine düşen pay.'),
              const SizedBox(height: 8),
              _memberTable(context, report),
              const SizedBox(height: 24),
              Text('Giderler', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final expense in report.expenses)
                Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(expense.title),
                    subtitle: Text(
                      '${_dateLabel(expense.createdAt)} · '
                      'Ödeyen: ${_memberName(expense.paidById)}',
                    ),
                    trailing: Text(formatMoney(expense.amountInKurus)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberTable(BuildContext context, MonthlyExpenseReport report) {
    final colors = Theme.of(context).colorScheme;
    final memberIds = {
      ...widget.members.keys,
      ...report.paidByMember.keys,
      ...report.sharesByMember.keys,
    }.toList()..sort((a, b) => _memberName(a).compareTo(_memberName(b)));

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(1.15),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: colors.outlineVariant),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: colors.surfaceContainerHighest),
            children: [
              _cell('Üye', heading: true),
              _cell('Ödediği', heading: true, numeric: true),
              _cell('Gider payı', heading: true, numeric: true),
            ],
          ),
          for (final id in memberIds)
            TableRow(
              children: [
                _cell(_memberName(id)),
                _cell(formatMoney(report.paidByMember[id] ?? 0), numeric: true),
                _cell(formatMoney(report.sharesByMember[id] ?? 0), numeric: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool heading = false, bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        textAlign: numeric ? TextAlign.end : TextAlign.start,
        style: heading ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
    );
  }
}
