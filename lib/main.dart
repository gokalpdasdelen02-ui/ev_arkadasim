import 'package:flutter/material.dart';

import 'add_expense_page.dart';
import 'models/expense.dart';
import 'services/balance_calculator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ev Arkadaşım',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF287568),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _members = {'me': 'Sen', 'ayse': 'Ayşe', 'zeynep': 'Zeynep'};

  final List<Expense> _expenses = [];

  Future<void> _openAddExpensePage() async {
    final expense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute<Expense>(builder: (context) => const AddExpensePage()),
    );

    if (!mounted || expense == null) {
      return;
    }

    setState(() {
      _expenses.insert(0, expense);
    });
  }

  @override
  Widget build(BuildContext context) {
    final balances = calculateBalances(userId: 'me', expenses: _expenses);

    final debts = balances.entries.where((entry) => entry.value < 0).toList();

    final receivables = balances.entries
        .where((entry) => entry.value > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ev Arkadaşım'),
        backgroundColor: const Color(0xFFF6F8FA),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(
            'Evde hesaplar net.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kime borcun var, kimden alacağın var?',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const Chip(
            avatar: Icon(Icons.science_outlined, size: 18),
            label: Text('Deneme modu · Kalıcı kayıt yok'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Eklediğin giderler uygulama yeniden başlatılınca silinir.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          BalanceSection(
            title: 'Borçlarım',
            description: 'Ödemen gereken tutarlar',
            items: debts,
            members: _members,
            emptyMessage: 'Kimseye borcun yok.',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFAD4B35),
          ),
          const SizedBox(height: 24),
          BalanceSection(
            title: 'Alacaklarım',
            description: 'Sana ödenecek tutarlar',
            items: receivables,
            members: _members,
            emptyMessage: 'Kimseden alacağın yok.',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF287568),
          ),
          const SizedBox(height: 28),
          Text(
            'Son giderler',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_expenses.isEmpty)
            const Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Henüz gider eklenmedi. İlk giderini ekleyebilirsin.',
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              color: Colors.white,
              child: Column(
                children: [
                  for (var index = 0; index < _expenses.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ExpenseTile(
                      title: _expenses[index].title,
                      subtitle:
                          'Ödeyen: ${_members[_expenses[index].paidById]}'
                          ' · ${_expenses[index].shares.length} kişi',
                      amountInKurus: _expenses[index].amountInKurus,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpensePage,
        icon: const Icon(Icons.add),
        label: const Text('Gider ekle'),
      ),
    );
  }
}

class BalanceSection extends StatelessWidget {
  const BalanceSection({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    required this.members,
    required this.emptyMessage,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final List<MapEntry<String, int>> items;
  final Map<String, String> members;
  final String emptyMessage;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(emptyMessage)
        else
          for (final item in items)
            Card(
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  members[item.key] ?? 'Üye',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  formatMoney(item.value.abs()),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountInKurus,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int amountInKurus;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        formatMoney(amountInKurus),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

// Para tutarlarını kuruş cinsinden tam sayı olarak tutuyoruz.
String formatMoney(int kurus) {
  final lira = kurus ~/ 100;
  final kalanKurus = (kurus % 100).toString().padLeft(2, '0');
  return '$lira,$kalanKurus TL';
}
