import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'login_page.dart';

import 'add_expense_page.dart';
import 'models/expense.dart';
import 'models/payment.dart';
import 'money.dart';
import 'monthly_expenses_page.dart';
import 'payment_widgets.dart';
import 'services/balance_calculator.dart';
import 'services/expense_service.dart';
import 'services/payment_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';

import 'household_gate.dart';
import 'models/household.dart';

import 'package:flutter/services.dart';

import 'services/household_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authState;

  @override
  void initState() {
    super.initState();
    _authState = AuthService().authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authState,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Oturum kontrol edilemedi. '
                    'Lütfen uygulamayı yeniden başlat.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return HouseholdGate(
          key: ValueKey(user.uid),
          uid: user.uid,
          homeBuilder: (household) => HomePage(
            key: ValueKey(household.id),
            household: household,
            userId: user.uid,
          ),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.household, required this.userId});

  final Household household;
  final String userId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  final _householdService = HouseholdService();
  final _expenseService = ExpenseService();
  final _paymentService = PaymentService();
  late Stream<Map<String, String>> _memberNames;
  late Stream<List<Expense>> _sharedExpenses;
  late Stream<List<Payment>> _payments;
  bool _isSigningOut = false;
  bool _savingMemberName = false;
  bool _creatingInvite = false;
  bool _savingPayment = false;

  @override
  void initState() {
    super.initState();
    _memberNames = _householdService.watchMemberNames(widget.household.id);
    _sharedExpenses = _expenseService.watchExpenses(widget.household.id);
    _payments = _watchPayments();
  }

  Stream<List<Payment>> _watchPayments() {
    return _paymentService.watchPayments(widget.household.id, widget.userId);
  }

  void _retryPayments() {
    setState(() {
      _payments = _watchPayments();
    });
  }

  void _retryMembers() {
    setState(() {
      _memberNames = _householdService.watchMemberNames(widget.household.id);
    });
  }

  void _retryExpenses() {
    setState(() {
      _sharedExpenses = _expenseService.watchExpenses(widget.household.id);
    });
  }

  Future<void> _editMemberName(String? currentName) async {
    if (_savingMemberName || _isSigningOut) return;

    final formKey = GlobalKey<FormState>();
    var input = currentName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Evde görünen adın'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: currentName,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Adın'),
            onChanged: (value) => input = value,
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty || trimmed.length > 40) {
                return '1 ile 40 karakter arasında bir ad gir.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, input.trim());
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;

    setState(() => _savingMemberName = true);
    try {
      await _householdService.saveMemberName(
        householdId: widget.household.id,
        uid: widget.userId,
        name: name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adın kaydedilemedi. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMemberName = false);
    }
  }

  Future<void> _openAddExpensePage(Map<String, String> members) async {
    final expense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute<Expense>(
        builder: (context) => AddExpensePage(
          userId: widget.userId,
          members: members,
          onSave: (expense) => _expenseService.addExpense(
            widget.household.id,
            expense,
          ),
        ),
      ),
    );

    if (!mounted || expense == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gider kaydedildi.')),
    );
  }

  Future<void> _runPaymentChange(
    Future<void> Function() change,
    String success,
  ) async {
    if (_savingPayment || _isSigningOut) return;
    setState(() => _savingPayment = true);

    String message;
    try {
      await change();
      message = success;
    } catch (error) {
      debugPrint('Ödeme bildirimi işlemi başarısız: $error');
      message = 'İşlem tamamlanamadı. Bildirimin durumunu kontrol et.';
    } finally {
      if (mounted) setState(() => _savingPayment = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _reportPayment(
    String creditorId,
    String creditorName,
    int debtInKurus,
  ) async {
    if (_savingPayment || _isSigningOut) return;

    final amount = await showPaymentAmountDialog(
      context: context,
      creditorName: creditorName,
      maxAmountInKurus: debtInKurus > Payment.maxAmountInKurus
          ? Payment.maxAmountInKurus
          : debtInKurus,
    );
    if (!mounted || amount == null) return;

    await _runPaymentChange(
      () => _paymentService.reportPayment(
        householdId: widget.household.id,
        debtorId: widget.userId,
        creditorId: creditorId,
        amountInKurus: amount,
      ),
      'Ödeme bildirildi. Alacaklının onayı bekleniyor.',
    );
  }

  Future<void> _decidePayment(Payment payment, PaymentStatus decision) async {
    if (_savingPayment || _isSigningOut) return;
    final approve = decision == PaymentStatus.approved;
    final amount = formatMoney(payment.amountInKurus);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Ödemeyi aldın mı?' : 'Bildirimi reddet'),
        content: Text(
          approve
              ? '$amount tutarındaki ödemeyi aldığını onaylıyor musun?'
              : '$amount tutarındaki bildirim reddedilirse bakiye değişmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Ödemeyi aldım' : 'Reddet'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    await _runPaymentChange(
      () => _paymentService.resolvePayment(
        householdId: widget.household.id,
        paymentId: payment.id,
        status: decision,
      ),
      approve ? 'Ödeme onaylandı.' : 'Ödeme bildirimi reddedildi.',
    );
  }

  Future<void> _createInvite() async {
    if (_creatingInvite) return;
    setState(() => _creatingInvite = true);

    try {
      final code = await _householdService.createInviteCode(
        widget.household.id,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Davet kodu'),
          content: SelectableText('$code\n\nTek kullanımlık · 24 saat geçerli'),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Kodu kopyala'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Davet kodu oluşturulamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingInvite = false);
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Çıkış yapılamadı. Lütfen tekrar dene.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: _memberNames,
      builder: (context, members) => StreamBuilder<List<Expense>>(
        stream: _sharedExpenses,
        builder: (context, expenses) => StreamBuilder<List<Payment>>(
          stream: _payments,
          builder: (context, payments) => _buildHome(
            context,
            members,
            expenses,
            payments,
          ),
        ),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    AsyncSnapshot<Map<String, String>> snapshot,
    AsyncSnapshot<List<Expense>> expenseSnapshot,
    AsyncSnapshot<List<Payment>> paymentSnapshot,
  ) {
    final members = snapshot.data ?? const <String, String>{};
    final currentName = members[widget.userId];
    final expenses = expenseSnapshot.data ?? const <Expense>[];
    final canViewMonthlyReport =
        !_isSigningOut && expenseSnapshot.hasData && snapshot.hasData;
    final payments = paymentSnapshot.data ?? const <Payment>[];
    final pendingCreditors = {
      for (final payment in payments)
        if (payment.debtorId == widget.userId &&
            payment.status == PaymentStatus.pending)
          payment.creditorId,
    };
    final canAddExpense =
        !_isSigningOut &&
        !_savingMemberName &&
        currentName != null &&
        expenseSnapshot.hasData;
    final balances = calculateBalances(
      userId: widget.userId,
      expenses: expenses,
      payments: payments,
    );

    final debts = balances.entries.where((entry) => entry.value < 0).toList();

    final receivables = balances.entries
        .where((entry) => entry.value > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ev Arkadaşım'),
        backgroundColor: const Color(0xFFF6F8FA),
        actions: [
          if (widget.household.isOwner)
            IconButton(
              tooltip: 'Davet kodu oluştur',
              onPressed: _creatingInvite || _isSigningOut
                  ? null
                  : _createInvite,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(
            widget.household.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kime borcun var, kimden alacağın var?',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: canViewMonthlyReport
                  ? () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => MonthlyExpensesPage(
                          expenses: expenses,
                          members: members,
                        ),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Aylık gider tablosu'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ev üyeleri', style: Theme.of(context).textTheme.titleMedium),
          if (snapshot.hasError) ...[
            const Text('Ev üyeleri yüklenemedi.'),
            TextButton(onPressed: _retryMembers, child: const Text('Tekrar dene')),
          ] else if (!snapshot.hasData)
            const LinearProgressIndicator()
          else ...[
            if (members.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final member in members.entries)
                    Chip(
                      label: Text(
                        member.key == widget.userId
                            ? '${member.value} (sen)'
                            : member.value,
                      ),
                    ),
                ],
              ),
            if (members.length < 2)
              const Text('Ev arkadaşların adlarını kaydedince burada görünür.'),
            if (currentName == null)
              const Text('Gider eklemek için önce görünen adını kaydet.'),
            TextButton(
              onPressed: _savingMemberName || _isSigningOut
                  ? null
                  : () => _editMemberName(currentName),
              child: Text(
                _savingMemberName
                    ? 'Ad kaydediliyor…'
                    : currentName == null
                    ? 'Görünen adımı ekle'
                    : 'Görünen adımı düzenle',
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (expenseSnapshot.hasError) ...[
            const Text('Ortak giderler yüklenemedi.'),
            TextButton(
              onPressed: _retryExpenses,
              child: const Text('Tekrar dene'),
            ),
          ] else if (paymentSnapshot.hasError) ...[
            const Text('Ödeme bildirimleri yüklenemedi.'),
            TextButton(onPressed: _retryPayments, child: const Text('Tekrar dene')),
          ] else if (!expenseSnapshot.hasData || !paymentSnapshot.hasData)
            const LinearProgressIndicator()
          else ...[
            BalanceSection(
              title: 'Borçlarım',
              description: 'Ödemen gereken tutarlar',
              items: debts,
              members: members,
              emptyMessage: 'Kimseye borcun yok.',
              icon: Icons.arrow_upward_rounded,
              color: const Color(0xFFAD4B35),
              buildAction: (debt) {
                if (pendingCreditors.contains(debt.key)) {
                  return const Text('Ödeme onayı bekleniyor');
                }
                final name = members[debt.key];
                if (name == null || currentName == null) return null;

                return TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _savingPayment || _isSigningOut
                      ? null
                      : () => _reportPayment(debt.key, name, -debt.value),
                  child: const Text('Ödeme bildir'),
                );
              },
            ),
            const SizedBox(height: 24),
            BalanceSection(
              title: 'Alacaklarım',
              description: 'Sana ödenecek tutarlar',
              items: receivables,
              members: members,
              emptyMessage: 'Kimseden alacağın yok.',
              icon: Icons.arrow_downward_rounded,
              color: const Color(0xFF287568),
            ),
            const SizedBox(height: 28),
            if (_savingPayment) const LinearProgressIndicator(),
            PaymentSection(
              userId: widget.userId,
              members: members,
              payments: payments,
              busy: _savingPayment || _isSigningOut,
              onDecision: _decidePayment,
            ),
            const SizedBox(height: 28),
            Text(
              'Son giderler',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
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
                    for (var index = 0; index < expenses.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ExpenseTile(
                        title: expenses[index].title,
                        subtitle:
                            'Ödeyen: ${members[expenses[index].paidById] ?? 'Üye'}'
                            ' · ${expenses[index].shares.length} kişi',
                        amountInKurus: expenses[index].amountInKurus,
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAddExpense ? () => _openAddExpensePage(members) : null,
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
    this.buildAction,
  });

  final String title;
  final String description;
  final List<MapEntry<String, int>> items;
  final Map<String, String> members;
  final String emptyMessage;
  final IconData icon;
  final Color color;
  final Widget? Function(MapEntry<String, int>)? buildAction;

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
                subtitle: buildAction?.call(item),
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
