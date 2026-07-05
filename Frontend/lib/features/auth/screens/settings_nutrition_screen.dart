import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/nutrition/domain/entities/nutrition_preferences.dart';
import '../../../features/nutrition/presentation/state/diet_provider.dart';

class SettingsNutritionScreen extends StatefulWidget {
  const SettingsNutritionScreen({super.key});

  @override
  State<SettingsNutritionScreen> createState() =>
      _SettingsNutritionScreenState();
}

class _SettingsNutritionScreenState extends State<SettingsNutritionScreen> {
  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFCC7A4A);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9E9E9E);

  late NutritionPreferences _prefs;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _prefs = context.read<DietProvider>().nutritionPreferences;
  }

  Future<void> _save() async {
    await context.read<DietProvider>().saveNutritionPreferences(_prefs);
    if (mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beslenme tercihleri kaydedildi'),
          backgroundColor: Color(0xFF388E3C),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _update(NutritionPreferences updated) {
    setState(() {
      _prefs = updated;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Beslenme Tercihleri',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text(
                'Kaydet',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('DİYET'),
          _buildCard([
            _prefTile(
              icon: Icons.grass_rounded,
              iconColor: const Color(0xFF4CAF50),
              title: 'Vejetaryen',
              subtitle: 'Et içermeyen besinleri göster',
              value: _prefs.vegetarian,
              onChanged: (v) => _update(
                _prefs.copyWith(vegetarian: v, vegan: v ? false : _prefs.vegan),
              ),
            ),
            _divider(),
            _prefTile(
              icon: Icons.eco_rounded,
              iconColor: const Color(0xFF8BC34A),
              title: 'Vegan',
              subtitle: 'Hayvansal ürün içermeyen besinler',
              value: _prefs.vegan,
              onChanged: (v) => _update(
                _prefs.copyWith(
                  vegan: v,
                  vegetarian: v ? true : _prefs.vegetarian,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader('SAĞLIK & ALERJİ'),
          _buildCard([
            _prefTile(
              icon: Icons.water_drop_outlined,
              iconColor: const Color(0xFF42A5F5),
              title: 'Laktozsuz',
              subtitle: 'Süt ürünü içermeyen alternatifleri öner',
              value: _prefs.lactoseFree,
              onChanged: (v) => _update(_prefs.copyWith(lactoseFree: v)),
            ),
            _divider(),
            _prefTile(
              icon: Icons.grain_rounded,
              iconColor: const Color(0xFFFFA726),
              title: 'Glutensiz',
              subtitle: 'Gluten içermeyen ürünleri filtrele',
              value: _prefs.glutenFree,
              onChanged: (v) => _update(_prefs.copyWith(glutenFree: v)),
            ),
          ]),
          const SizedBox(height: 24),
          if (_prefs.hasAnyFilter)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seçili filtreler besin aramasına ve tarif önerilerine uygulanır.',
                      style: TextStyle(
                        color: _textPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              heroTag: 'settings_nutrition_save_fab',
              onPressed: _save,
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Kaydet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _prefTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _textSecondary, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: _accent,
        activeTrackColor: _accent.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.white12,
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    indent: 72,
    endIndent: 16,
    color: Colors.white10,
  );
}
