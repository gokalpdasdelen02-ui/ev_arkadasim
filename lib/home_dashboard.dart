import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/expense.dart';
import 'models/household.dart';
import 'models/payment.dart';
import 'money.dart';
import 'monthly_expenses_page.dart';
import 'payment_widgets.dart';
import 'services/balance_calculator.dart';

enum _HomeTab { summary, expenses, payments }

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.household,
    required this.userId,
    required this.names,
    required this.expenses,
    required this.payments,
    required this.signingOut,
    required this.savingName,
    required this.creatingInvite,
    required this.savingPayment,
    required this.onRetryMembers,
    required this.onRetryExpenses,
    required this.onRetryPayments,
    required this.onEditName,
    required this.onInvite,
    required this.onSignOut,
    required this.onAddExpense,
    required this.onReportPayment,
    required this.onDecidePayment,
  });

  final Household household;
  final String userId;
  final AsyncSnapshot<Map<String, String>> names;
  final AsyncSnapshot<List<Expense>> expenses;
  final AsyncSnapshot<List<Payment>> payments;
  final bool signingOut, savingName, creatingInvite, savingPayment;
  final VoidCallback onRetryMembers, onRetryExpenses, onRetryPayments;
  final Future<void> Function(String?) onEditName;
  final VoidCallback onInvite, onSignOut;
  final Future<void> Function(Map<String, String>) onAddExpense;
  final Future<bool> Function(String, String, int) onReportPayment;
  final Future<void> Function(Payment, PaymentStatus) onDecidePayment;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _scrollPositions = PageStorageBucket();
  _HomeTab _tab = _HomeTab.summary;
  bool _settings = false;

  Map<String, String> get _members => widget.names.data ?? const {};
  List<Expense> get _expenses => widget.expenses.data ?? const [];
  List<Payment> get _payments => widget.payments.data ?? const [];
  String? get _name => _members[widget.userId];
  bool get _canAdd =>
      !widget.signingOut &&
      !widget.savingName &&
      _name != null &&
      widget.expenses.hasData;

  void _selectTab(_HomeTab tab) => setState(() {
    _tab = tab;
    _settings = false;
  });

  void _toggleSettings() => setState(() => _settings = !_settings);

  Future<void> _reportPayment(
    String creditorId,
    String name,
    int amount,
  ) async {
    final completed = await widget.onReportPayment(creditorId, name, amount);
    if (completed && mounted && !_settings && _tab == _HomeTab.summary) {
      _selectTab(_HomeTab.payments);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _payments
        .where(
          (payment) =>
              payment.creditorId == widget.userId &&
              payment.status == PaymentStatus.pending,
        )
        .length;
    final typography = Theme.of(context).textTheme;
    final selectedIconColor = Theme.of(context).colorScheme.primary;

    return PopScope<Object?>(
      canPop: !_settings,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _settings) _toggleSettings();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ev Arkadaşım', style: typography.bodySmall),
                          const SizedBox(height: 2),
                          Text(
                            widget.household.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _toggleSettings,
                      icon: Icon(
                        _settings ? Icons.arrow_back : Icons.settings_outlined,
                        size: 18,
                      ),
                      label: Text(_settings ? 'Geri' : 'Ev ayarları'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageStorage(
                  bucket: _scrollPositions,
                  child: _settings
                      ? _list('settings', _settingsContent())
                      : switch (_tab) {
                          _HomeTab.summary => _list(
                            'summary',
                            _summary(context, pending),
                          ),
                          _HomeTab.expenses => _expensePage(context),
                          _HomeTab.payments => _list(
                            'payments',
                            _paymentContent(),
                          ),
                        },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_settings && _tab != _HomeTab.payments)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _canAdd
                        ? () => widget.onAddExpense(_members)
                        : null,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Gider ekle'),
                  ),
                ),
              ),
            const Divider(height: 1),
            NavigationBar(
              height: 68,
              selectedIndex: _tab.index,
              onDestinationSelected: (index) =>
                  _selectTab(_HomeTab.values[index]),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: Icon(
                    Icons.home_outlined,
                    color: selectedIconColor,
                  ),
                  label: 'Özet',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(
                    Icons.receipt_long_outlined,
                    color: selectedIconColor,
                  ),
                  label: 'Giderler',
                ),
                NavigationDestination(
                  icon: _paymentIcon(pending),
                  selectedIcon: _paymentIcon(pending, color: selectedIconColor),
                  label: 'Ödemeler',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentIcon(int pending, {Color? color}) {
    final icon = Icon(Icons.account_balance_wallet_outlined, color: color);
    if (pending == 0) return icon;
    return Badge(
      label: Semantics(
        label: '$pending ödeme onayını bekliyor',
        child: ExcludeSemantics(child: Text(pending > 99 ? '99+' : '$pending')),
      ),
      backgroundColor: AppTheme.attentionBackground(context),
      textColor: AppTheme.attention(context),
      child: icon,
    );
  }

  Widget _list(String storageKey, List<Widget> children) => ListView(
    key: PageStorageKey(storageKey),
    padding: AppTheme.pagePadding,
    children: children,
  );

  Widget _heading(String title) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);

  Widget _note(String message, {String? action, VoidCallback? onAction}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (action != null)
                TextButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      );

  Widget _nameNotice() {
    if (widget.names.hasError) {
      return _note(
        'Ev üyeleri yüklenemedi.',
        action: 'Tekrar dene',
        onAction: widget.onRetryMembers,
      );
    }
    if (!widget.names.hasData) return const LinearProgressIndicator();
    return _note(
      'Gider eklemek için önce evde görünen adını kaydet.',
      action: 'Görünen adımı ekle',
      onAction: widget.signingOut || widget.savingName
          ? null
          : () => widget.onEditName(null),
    );
  }

  List<Widget> _summary(BuildContext context, int pending) {
    if (widget.expenses.hasError) {
      return [
        _note(
          'Ortak giderler yüklenemedi.',
          action: 'Tekrar dene',
          onAction: widget.onRetryExpenses,
        ),
      ];
    }
    if (widget.payments.hasError) {
      return [
        _note(
          'Ödemeler yüklenemedi.',
          action: 'Tekrar dene',
          onAction: widget.onRetryPayments,
        ),
      ];
    }
    if (!widget.expenses.hasData || !widget.payments.hasData) {
      return [const LinearProgressIndicator()];
    }

    final balances = calculateBalances(
      userId: widget.userId,
      expenses: _expenses,
      payments: _payments,
    );
    final debts = balances.entries.where((entry) => entry.value < 0).toList();
    final credits = balances.entries.where((entry) => entry.value > 0).toList();
    final pendingCreditors = {
      for (final payment in _payments)
        if (payment.debtorId == widget.userId &&
            payment.status == PaymentStatus.pending)
          payment.creditorId,
    };

    return [
      _BalanceTotals(
        debt: debts.fold(0, (sum, item) => sum - item.value),
        credit: credits.fold(0, (sum, item) => sum + item.value),
      ),
      if (pending > 0) ...[
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: Icon(Icons.schedule, color: AppTheme.attention(context)),
            title: Text('$pending ödeme onayını bekliyor'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectTab(_HomeTab.payments),
          ),
        ),
      ],
      if (_name == null) ...[const SizedBox(height: 12), _nameNotice()],
      const SizedBox(height: 18),
      _heading('Kime borcum var?'),
      const SizedBox(height: 8),
      _balanceRows(
        debts,
        'Kimseye borcun yok.',
        pendingCreditors: pendingCreditors,
      ),
      const SizedBox(height: 16),
      _heading('Kimden alacağım var?'),
      const SizedBox(height: 8),
      _balanceRows(credits, 'Kimseden alacağın yok.'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _heading('Son giderler')),
          TextButton(
            onPressed: () => _selectTab(_HomeTab.expenses),
            child: const Text('Tümü'),
          ),
        ],
      ),
      if (_expenses.isEmpty)
        _note('Henüz gider eklenmedi.')
      else
        Card(
          child: Column(
            children: [
              for (final (index, expense) in _expenses.take(2).indexed) ...[
                if (index > 0) const Divider(height: 1),
                _expenseTile(expense),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _balanceRows(
    List<MapEntry<String, int>> balances,
    String emptyMessage, {
    Set<String>? pendingCreditors,
  }) {
    if (balances.isEmpty) return _note(emptyMessage);

    return Card(
      child: Column(
        children: [
          for (final (index, item) in balances.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _balanceRow(item, pendingCreditors),
          ],
        ],
      ),
    );
  }

  Widget _balanceRow(
    MapEntry<String, int> item,
    Set<String>? pendingCreditors,
  ) {
    final knownName = _members[item.key];
    final name = knownName ?? 'Üye';
    final money = formatMoney(item.value.abs());
    final isPending = pendingCreditors?.contains(item.key) ?? false;
    final canReport =
        pendingCreditors != null &&
        !isPending &&
        knownName != null &&
        _name != null;
    final theme = Theme.of(context);
    final member = ListTile(
      dense: true,
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(name.characters.first.toUpperCase()),
      ),
      title: Text(name, style: theme.textTheme.titleMedium),
      subtitle: Text(
        isPending ? '$money · Ödeme onayı bekleniyor' : money,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isPending ? AppTheme.attention(context) : null,
          fontFeatures: AppTheme.tabularFigures,
        ),
      ),
    );
    final action = canReport
        ? OutlinedButton(
            onPressed: widget.savingPayment || widget.signingOut
                ? null
                : () => _reportPayment(item.key, knownName, -item.value),
            child: const Text('Ödeme bildir'),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return member;
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [member, action, const SizedBox(height: 4)],
            );
          }
          return Row(
            children: [
              Expanded(child: member),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _expensePage(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('expenses'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('Giderler'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Aylık gider tablosu'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled:
                      !widget.signingOut &&
                      widget.expenses.hasData &&
                      widget.names.hasData,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => MonthlyExpensesPage(
                        expenses: _expenses,
                        members: _members,
                      ),
                    ),
                  ),
                ),
              ),
              if (_name == null) ...[const SizedBox(height: 12), _nameNotice()],
              const SizedBox(height: 12),
              if (widget.expenses.hasError)
                _note(
                  'Ortak giderler yüklenemedi.',
                  action: 'Tekrar dene',
                  onAction: widget.onRetryExpenses,
                )
              else if (!widget.expenses.hasData)
                const LinearProgressIndicator()
              else if (_expenses.isEmpty)
                _note('Henüz gider eklenmedi. İlk giderini ekleyebilirsin.'),
            ],
          ),
        ),
      ),
      if (widget.expenses.hasData)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.builder(
            itemCount: _expenses.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: _expenseTile(_expenses[index], showDate: true),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _expenseTile(Expense expense, {bool showDate = false}) {
    final theme = Theme.of(context);
    final payer = expense.paidById == widget.userId
        ? 'Sen ödedin'
        : '${_members[expense.paidById] ?? 'Üye'} ödedi';
    final date = expense.createdAt.toLocal();

    return ListTile(
      leading: Icon(
        Icons.receipt_long_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(expense.title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        '$payer · ${expense.shares.length} kişi'
        '${showDate ? ' · ${date.day}.${date.month}.${date.year}' : ''}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        formatMoney(expense.amountInKurus),
        style: theme.textTheme.titleMedium?.copyWith(
          fontFeatures: AppTheme.tabularFigures,
        ),
      ),
    );
  }

  List<Widget> _paymentContent() => [
    _heading('Ödemeler'),
    const SizedBox(height: 12),
    if (widget.payments.hasError)
      _note(
        'Ödemeler yüklenemedi.',
        action: 'Tekrar dene',
        onAction: widget.onRetryPayments,
      )
    else if (!widget.payments.hasData)
      const LinearProgressIndicator()
    else ...[
      if (widget.savingPayment) const LinearProgressIndicator(),
      PaymentSection(
        userId: widget.userId,
        members: _members,
        payments: _payments,
        busy: widget.savingPayment || widget.signingOut,
        onDecision: widget.onDecidePayment,
      ),
    ],
  ];

  List<Widget> _settingsContent() => [
    _heading('Ev ayarları'),
    const SizedBox(height: 12),
    Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Ev üyeleri'),
            subtitle: Text(
              _members.isEmpty
                  ? 'Ev arkadaşların adlarını kaydedince burada görünür.'
                  : _members.entries
                        .map(
                          (entry) => entry.key == widget.userId
                              ? '${entry.value} (sen)'
                              : entry.value,
                        )
                        .join(', '),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            enabled:
                !widget.signingOut &&
                !widget.savingName &&
                widget.names.hasData,
            leading: const Icon(Icons.person_outline),
            title: const Text('Görünen ad'),
            subtitle: Text(
              widget.savingName
                  ? 'Ad kaydediliyor…'
                  : _name ?? 'Görünen adımı ekle',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onEditName(_name),
          ),
          if (widget.household.isOwner) ...[
            const Divider(height: 1),
            ListTile(
              enabled: !widget.signingOut && !widget.creatingInvite,
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Davet kodu oluştur'),
              subtitle: Text(
                widget.creatingInvite
                    ? 'Kod hazırlanıyor…'
                    : 'Tek kullanımlık · 24 saat geçerli',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onInvite,
            ),
          ],
        ],
      ),
    ),
    if (widget.names.hasError || !widget.names.hasData) ...[
      const SizedBox(height: 12),
      _nameNotice(),
    ],
    const SizedBox(height: 16),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: widget.signingOut ? null : widget.onSignOut,
        icon: const Icon(Icons.logout),
        label: Text(widget.signingOut ? 'Çıkış yapılıyor…' : 'Çıkış yap'),
      ),
    ),
  ];
}

class _BalanceTotals extends StatelessWidget {
  const _BalanceTotals({required this.debt, required this.credit});

  final int debt, credit;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    Widget total(String label, int amount) => Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: type.bodySmall),
            const SizedBox(height: 4),
            Text(
              formatMoney(amount),
              style: type.headlineMedium?.copyWith(
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(26) > 36) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              total('Borçlarım', debt),
              const SizedBox(height: 8),
              total('Alacaklarım', credit),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: total('Borçlarım', debt)),
            const SizedBox(width: 8),
            Expanded(child: total('Alacaklarım', credit)),
          ],
        );
      },
    );
  }
}
