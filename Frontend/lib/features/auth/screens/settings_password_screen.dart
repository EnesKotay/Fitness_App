import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsPasswordScreen extends StatefulWidget {
  const SettingsPasswordScreen({super.key});

  @override
  State<SettingsPasswordScreen> createState() => _SettingsPasswordScreenState();
}

class _SettingsPasswordScreenState extends State<SettingsPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _currentCtrl.text.trim(),
      newPassword: _newCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre başarıyla güncellendi.')),
      );
      return;
    }
    final msg = auth.errorMessage ?? 'Şifre güncellenemedi';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Değiştir')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: _hideCurrent,
                decoration: InputDecoration(
                  labelText: 'Mevcut sifre',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                    icon: Icon(
                      _hideCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Mevcut sifre gerekli'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newCtrl,
                obscureText: _hideNew,
                decoration: InputDecoration(
                  labelText: 'Yeni sifre',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hideNew = !_hideNew),
                    icon: Icon(
                      _hideNew ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.length < 6) return 'Şifre en az 6 karakter olmalı';
                  if (s == _currentCtrl.text.trim()) {
                    return 'Yeni sifre mevcut sifre ile ayni olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _hideConfirm,
                decoration: InputDecoration(
                  labelText: 'Yeni sifre (tekrar)',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                    icon: Icon(
                      _hideConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').trim() != _newCtrl.text.trim()) {
                    return 'Şifreler eşleşmiyor';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: loading ? null : _submit,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(loading ? 'Güncelleniyor...' : 'Şifreyi Güncelle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
