import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'models/household.dart';
import 'services/auth_service.dart';
import 'services/household_service.dart';

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({
    super.key,
    required this.uid,
    required this.homeBuilder,
  });

  final String uid;
  final Widget Function(Household) homeBuilder;

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  final _service = HouseholdService();
  final _nameController = TextEditingController();

  late Future<Household?> _household;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _household = _service.getHousehold(widget.uid);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _household = _service.getHousehold(widget.uid);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String errorMessage) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await action();
    } on FirebaseException catch (error) {
      debugPrint('Ev kurulumu: ${error.code}');
      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu işlem için izin verilmedi.'
            : errorMessage,
      );
    } catch (_) {
      _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createHousehold() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || name.length > 60) {
      _showMessage('1 ile 60 karakter arasında bir ev adı gir.');
      return;
    }

    FocusScope.of(context).unfocus();

    await _run(() async {
      final household = await _service.createHousehold(
        uid: widget.uid,
        name: name,
      );

      if (!mounted) return;
      setState(() {
        _household = Future<Household?>.value(household);
      });
    }, 'Ev oluşturulamadı. Lütfen tekrar dene.');
  }

  Future<void> _joinHousehold() async {
    if (_busy) return;
    var input = '';

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eve katıl'),
        content: TextField(
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Davet kodu'),
          onChanged: (value) => input = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );

    if (!mounted || code == null) return;

    await _run(() async {
      final joined = await _service.joinWithInvite(
        uid: widget.uid,
        input: code,
      );
      if (!mounted) return;

      if (joined) {
        _retry(); // Yeni üyeliği okuyup evin ana ekranını açar.
      } else {
        _showMessage('Bu davet kodu geçersiz veya daha önce kullanılmış.');
      }
    }, 'Eve katılınamadı. Kodu ve bağlantını kontrol et.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Household?>(
      future: _household,
      builder: (context, snapshot) {
        final household = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            household != null) {
          return widget.homeBuilder(household);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ev Arkadaşım'),
            actions: [
              IconButton(
                tooltip: 'Çıkış yap',
                icon: const Icon(Icons.logout),
                onPressed: _busy
                    ? null
                    : () => _run(
                        AuthService().signOut,
                        'Çıkış yapılamadı. Lütfen tekrar dene.',
                      ),
              ),
            ],
          ),
          body: SafeArea(child: _buildBody(snapshot)),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<Household?> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (snapshot.hasError) ...[
          const Text('Ev bilgisi okunamadı.'),
          TextButton(onPressed: _retry, child: const Text('Tekrar dene')),
        ] else ...[
          Text(
            'İlk evini oluştur',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Ortak giderlerini takip etmek için evine bir ad ver.'),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ev adı',
              hintText: 'Örneğin: Bizim Ev',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _createHousehold,
            child: Text(_busy ? 'Ev oluşturuluyor…' : 'Ev oluştur'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _joinHousehold,
            child: const Text('Davet koduyla katıl'),
          ),
        ],
      ],
    );
  }
}
