import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Lütfen e-posta ve şifreni gir.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegistering) {
        await _authService.register(email: email, password: password);
      } else {
        await _authService.signIn(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'invalid-email' => 'Geçerli bir e-posta adresi gir.',
        'email-already-in-use' =>
          'Bu e-posta adresi zaten kullanılıyor. Giriş yapabilirsin.',
        'weak-password' =>
          'Şifre yeterince güçlü değil. Daha güçlü bir şifre seç.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'E-posta veya şifre hatalı.',
        'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Bir süre sonra tekrar dene.',
        'network-request-failed' =>
          'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
        _ => 'İşlem tamamlanamadı. Lütfen tekrar dene.',
      };

      _showMessage(message);
    } catch (_) {
      _showMessage('Beklenmeyen bir hata oluştu. Lütfen tekrar dene.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ev Arkadaşım')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 24),
            Text(
              _isRegistering ? 'Hesap oluştur' : 'Hoş geldin',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _isRegistering
                  ? 'Ev hesabını takip etmek için hesabını oluştur.'
                  : 'Ev hesabını takip etmek için giriş yap.',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(
                _isLoading
                    ? 'Lütfen bekle…'
                    : (_isRegistering ? 'Hesap oluştur' : 'Giriş yap'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();

                      _passwordController.clear();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      setState(() {
                        _isRegistering = !_isRegistering;
                      });
                    },
              child: Text(
                _isRegistering
                    ? 'Zaten hesabın var mı? Giriş yap'
                    : 'Hesabın yok mu? Hesap oluştur',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
