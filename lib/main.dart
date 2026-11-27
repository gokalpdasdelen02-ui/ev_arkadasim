import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_expense_page.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'home_dashboard.dart';
import 'household_gate.dart';
import 'login_page.dart';
import 'models/expense.dart';
import 'models/household.dart';
import 'models/payment.dart';
import 'money.dart';
import 'payment_widgets.dart';
import 'services/auth_service.dart';
import 'services/expense_service.dart';
import 'services/household_service.dart';
import 'services/payment_service.dart';

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
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
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
          onSave: (expense) =>
              _expenseService.addExpense(widget.household.id, expense),
        ),
      ),
    );

    if (!mounted || expense == null) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Gider kaydedildi.')));
  }

  Future<bool> _runPaymentChange(
    Future<void> Function() change,
    String success,
  ) async {
    if (_savingPayment || _isSigningOut) return false;
    setState(() => _savingPayment = true);

    var completed = false;
    String message;
    try {
      await change();
      completed = true;
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
    return completed;
  }

  Future<bool> _reportPayment(
    String creditorId,
    String creditorName,
    int debtInKurus,
  ) async {
    if (_savingPayment || _isSigningOut) return false;

    final amount = await requestPaymentAmount(
      context: context,
      creditorName: creditorName,
      maxAmountInKurus: debtInKurus > Payment.maxAmountInKurus
          ? Payment.maxAmountInKurus
          : debtInKurus,
    );
    if (!mounted || amount == null) return false;

    return _runPaymentChange(
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
          builder: (context, payments) => HomeDashboard(
            household: widget.household,
            userId: widget.userId,
            names: members,
            expenses: expenses,
            payments: payments,
            signingOut: _isSigningOut,
            savingName: _savingMemberName,
            creatingInvite: _creatingInvite,
            savingPayment: _savingPayment,
            onRetryMembers: _retryMembers,
            onRetryExpenses: _retryExpenses,
            onRetryPayments: _retryPayments,
            onEditName: _editMemberName,
            onInvite: _createInvite,
            onSignOut: _signOut,
            onAddExpense: _openAddExpensePage,
            onReportPayment: _reportPayment,
            onDecidePayment: _decidePayment,
          ),
        ),
      ),
    );
  }
}
