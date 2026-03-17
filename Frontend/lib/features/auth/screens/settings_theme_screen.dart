import 'package:flutter/material.dart';
import '../../../core/utils/storage_helper.dart';

class SettingsThemeScreen extends StatefulWidget {
  const SettingsThemeScreen({super.key});

  @override
  State<SettingsThemeScreen> createState() => _SettingsThemeScreenState();
}

class _SettingsThemeScreenState extends State<SettingsThemeScreen> {
  String _mode = 'dark';
  bool _highContrast = false;

  @override
  void initState() {
    super.initState();
    _mode = StorageHelper.getThemeMode();
    _highContrast = StorageHelper.getThemeHighContrast();
  }

  Future<void> _save() async {
    await StorageHelper.saveThemeMode(_mode);
    await StorageHelper.saveThemeHighContrast(_highContrast);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tema tercihleri kaydedildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tema ve Gorunum')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tema Modu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'dark',
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Koyu'),
              ),
              ButtonSegment<String>(
                value: 'system',
                icon: Icon(Icons.phone_android_rounded),
                label: Text('Sistem'),
              ),
              ButtonSegment<String>(
                value: 'light',
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Acik'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _mode = selection.first);
              }
            },
          ),
          const Divider(height: 18),
          SwitchListTile(
            value: _highContrast,
            onChanged: (v) => setState(() => _highContrast = v),
            title: const Text('Yuksek kontrast'),
            subtitle: const Text('Kart ve metin okunabilirligini artir'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
