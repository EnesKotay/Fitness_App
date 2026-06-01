import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

/// AI Koç Ayarları
class CoachSettingsWidget extends StatefulWidget {
  const CoachSettingsWidget({super.key});

  @override
  State<CoachSettingsWidget> createState() => _CoachSettingsWidgetState();
}

class _CoachSettingsWidgetState extends State<CoachSettingsWidget> {
  String _selectedPersonality = 'SUPPORTIVE';

  final Map<String, Map<String, String>> _personalities = {
    'SUPPORTIVE': {
      'name': '✨ Destekleyici Koç',
      'desc': 'Pozitif, motive edici ve anlayışlı. Her zaman yanında.',
      'example': '"Harikasın! Bu haftayı çok iyi kapattın 💪"',
    },
    'TOUGH_LOVE': {
      'name': '💯 Sert Ama Sevgiyle',
      'desc': 'Direkt, net ve bahane kabul etmez. Ama daima yapıcı.',
      'example': '"3 gündür antrenman yok. Bugün başlıyoruz, tartışmasız."',
    },
    'ANALYTICAL': {
      'name': '📊 Analitik Koç',
      'desc': 'Veriye dayalı, objektif ve bilimsel yaklaşım.',
      'example': '"Volume %12 azaldı. Plato riski var, deload öneriyorum."',
    },
  };

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider?>()?.user?.id != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        const Text(
          '⚙️ AI Koç Ayarları',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI koçunun kişiliğini ve davranışını özelleştir',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),

        // Section: Koçluk Kişiliği
        _buildSectionTitle('Koçluk Kişiliği'),
        const SizedBox(height: 12),
        Text(
          'AI koçunun seninle nasıl konuşmasını istersin?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Personality cards
        ...(_personalities.entries.map((entry) {
          return _buildPersonalityCard(
            key: entry.key,
            name: entry.value['name']!,
            description: entry.value['desc']!,
            example: entry.value['example']!,
            isSelected: _selectedPersonality == entry.key,
          );
        }).toList()),

        const SizedBox(height: 32),

        // Premium banner (if not premium)
        if (!isPremium) _buildPremiumBanner(context),

        const SizedBox(height: 24),

        // Bilgi kartı
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00D9FF),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPersonalityCard({
    required String key,
    required String name,
    required String description,
    required String example,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPersonality = key;
        });
        // TODO: API call to update personality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name seçildi'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D9FF).withValues(alpha: 0.1)
              : const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D9FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00D9FF),
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      example,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium\'a Geç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sınırsız AI koç, özel analizler ve daha fazlası',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF00D9FF),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'İpucu: Kişilik seçimin tüm AI koç yanıtlarını etkiler. '
              'İstediğin zaman değiştirebilirsin.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
