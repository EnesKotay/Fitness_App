import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/preferences/app_preferences.dart';

class SettingsLanguageUnitsScreen extends StatelessWidget {
  const SettingsLanguageUnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final isEnglish = prefs.effectiveLanguageCode == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D12),
        elevation: 0,
        title: Text(isEnglish ? 'Language & Units' : 'Dil ve Birimler'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _HeaderCard(
            title: isEnglish ? 'US-friendly setup' : 'ABD uyumlu deneyim',
            subtitle: isEnglish
                ? 'Use English, imperial units, and US-style nutrition suggestions.'
                : 'İngilizce, imperial birimler ve ABD tarzı beslenme önerilerini aç.',
          ),
          const SizedBox(height: 18),
          _SectionTitle(isEnglish ? 'Language' : 'Dil'),
          _OptionGroup<AppLanguage>(
            value: prefs.language,
            items: [
              _Option(
                AppLanguage.system,
                isEnglish ? 'System' : 'Sistem',
                isEnglish ? 'Follow device language' : 'Cihaz dilini kullan',
              ),
              const _Option(AppLanguage.en, 'English', 'United States ready'),
              const _Option(AppLanguage.tr, 'Türkçe', 'Türkiye deneyimi'),
            ],
            onChanged: prefs.setLanguage,
          ),
          const SizedBox(height: 18),
          _SectionTitle(isEnglish ? 'Units' : 'Birimler'),
          _OptionGroup<AppUnitSystem>(
            value: prefs.unitSystem,
            items: [
              _Option(
                AppUnitSystem.system,
                isEnglish ? 'System' : 'Sistem',
                isEnglish
                    ? 'US devices use lb/in automatically'
                    : 'ABD cihazlarında lb/in otomatik gelir',
              ),
              const _Option(
                AppUnitSystem.imperial,
                'Imperial',
                'lb, in, fl oz',
              ),
              const _Option(AppUnitSystem.metric, 'Metric', 'kg, cm, L'),
            ],
            onChanged: prefs.setUnitSystem,
          ),
          const SizedBox(height: 18),
          _SectionTitle(isEnglish ? 'Food Region' : 'Yemek Bölgesi'),
          _OptionGroup<AppMarketRegion>(
            value: prefs.marketRegion,
            items: [
              _Option(
                AppMarketRegion.system,
                isEnglish ? 'System' : 'Sistem',
                isEnglish ? 'Match device region' : 'Cihaz bölgesini kullan',
              ),
              const _Option(
                AppMarketRegion.us,
                'United States',
                'Greek yogurt, oatmeal, turkey wrap',
              ),
              const _Option(
                AppMarketRegion.tr,
                'Türkiye',
                'Yoğurt, pilav, tavuk, ayran',
              ),
            ],
            onChanged: prefs.setMarketRegion,
          ),
          const SizedBox(height: 18),
          _PreviewCard(prefs: prefs, isEnglish: isEnglish),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2B22), Color(0xFF171A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.public_rounded, color: Color(0xFF81C784)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Option<T> {
  final T value;
  final String title;
  final String subtitle;

  const _Option(this.value, this.title, this.subtitle);
}

class _OptionGroup<T> extends StatelessWidget {
  final T value;
  final List<_Option<T>> items;
  final ValueChanged<T> onChanged;

  const _OptionGroup({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _OptionTile<T>(
              option: items[i],
              selected: items[i].value == value,
              onTap: () => onChanged(items[i].value),
            ),
            if (i != items.length - 1)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ],
        ],
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  final _Option<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF81C784)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final AppPreferences prefs;
  final bool isEnglish;

  const _PreviewCard({required this.prefs, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    final weight = AppUnits.formatWeight(80, prefs);
    final height = AppUnits.formatHeight(180, prefs);
    final water = AppUnits.formatWater(2, prefs);
    final foods = prefs.effectiveMarketRegion == 'US'
        ? 'Greek yogurt, oatmeal, turkey wrap'
        : 'Süzme yoğurt, yulaf, tavuk pilav';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish ? 'Preview' : 'Önizleme',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEnglish
                ? 'Weight $weight · Height $height · Water $water\nFood ideas: $foods'
                : 'Kilo $weight · Boy $height · Su $water\nYemek önerileri: $foods',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
