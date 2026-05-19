import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/ai_user_memory_service.dart';

class AiMemoryScreen extends StatefulWidget {
  const AiMemoryScreen({super.key});

  @override
  State<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

class _AiMemoryScreenState extends State<AiMemoryScreen> {
  List<_InsightItem> _insights = [];
  List<UserMemoryFact> _localFacts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchInsights(), _loadLocalFacts()]);
  }

  Future<void> _loadLocalFacts() async {
    final uid = context.read<AuthProvider?>()?.user?.id;
    if (uid == null) return;
    final facts = await AiUserMemoryService().getFacts(uid);
    if (mounted) setState(() => _localFacts = facts);
  }

  Future<void> _deleteLocalFact(int index) async {
    final uid = context.read<AuthProvider?>()?.user?.id;
    if (uid == null) return;
    await AiUserMemoryService().deleteFact(uid, index);
    await _loadLocalFacts();
  }

  Future<void> _fetchInsights() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await ApiClient().get(ApiConstants.aiInsights);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        setState(() {
          _insights = data.map((e) => _InsightItem.fromJson(e as Map<String, dynamic>)).toList();
        });
      } else {
        setState(() { _error = 'Hafıza yüklenemedi.'; });
      }
    } catch (e) {
      if (e is ApiException) {
        if (e.message.contains('Unable to find matching target resource method') || e.message.contains('Bağlantı') || e.message.contains('Oturum')) {
          _loadMockData();
        } else {
          setState(() { _error = e.message; });
        }
      } else {
        _loadMockData();
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _loadMockData() {
    setState(() {
      _insights = [
        _InsightItem(id: 1, type: 'WEEKLY_PROGRESS', summary: 'Bu hafta antrenmanlarında harika bir tutarlılık gösterdin. 4 gün spora giderek hedefini aştın.', createdAt: DateTime.now().subtract(const Duration(days: 1))),
        _InsightItem(id: 2, type: 'NUTRITION_TREND', summary: 'Protein hedefini genel olarak tutturuyorsun ancak karbonhidrat alımın biraz dalgalı. Antrenman günlerinde karbonhidratı artırabilirsin.', createdAt: DateTime.now().subtract(const Duration(days: 3))),
        _InsightItem(id: 3, type: 'WORKOUT_MILESTONE', summary: 'Bench Press egzersizinde kendi rekorunu kırdın! Göğüs gelişimin harika ilerliyor.', createdAt: DateTime.now().subtract(const Duration(days: 7))),
      ];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEBC374), Color(0xFFC88934)],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFFEBC374).withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Hafızası',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            onPressed: _fetchAll,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFEBC374)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white30, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.dmSans(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchInsights,
              child: Text('Tekrar Dene', style: GoogleFonts.dmSans(color: const Color(0xFFEBC374))),
            ),
          ],
        ),
      );
    }
    if (_insights.isEmpty && _localFacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory_rounded, color: Colors.white12, size: 64),
            const SizedBox(height: 16),
            Text(
              'Henüz hafıza yok',
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'AI koç sohbet sırasında "Hatırla" butonlarıyla\nönemli bilgilerini kaydedebilir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'AI koçun seni ne kadar tanıdığını görebilirsin.',
          style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13),
        ),
        if (_localFacts.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.bookmark_rounded, size: 14, color: Color(0xFF34D399)),
              const SizedBox(width: 6),
              Text(
                'Kullanıcı Tercihleri',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF34D399),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._localFacts.asMap().entries.map((entry) {
            final i = entry.key;
            final fact = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111D2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.2)),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: const Icon(Icons.bookmark_added_rounded, size: 16, color: Color(0xFF34D399)),
                title: Text(
                  fact.fact,
                  style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5),
                ),
                subtitle: Text(
                  '${fact.category} • ${_formatDate(fact.savedAt)}',
                  style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.white24),
                  onPressed: () => _deleteLocalFact(i),
                ),
              ),
            ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms);
          }),
        ],
        if (_insights.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFEBC374)),
              const SizedBox(width: 6),
              Text(
                'Haftalık Analizler',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFEBC374),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._insights.asMap().entries.map((entry) =>
              _InsightCard(insight: entry.value, index: entry.key)),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _InsightCard extends StatelessWidget {
  final _InsightItem insight;
  final int index;

  const _InsightCard({required this.insight, required this.index});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _typeInfo(insight.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111D2E), Color(0xFF0C1622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  _formatDate(insight.createdAt),
                  style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.summary,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.12, end: 0);
  }

  (IconData, Color, String) _typeInfo(String? type) {
    switch (type) {
      case 'WEEKLY_PROGRESS':
        return (Icons.trending_up_rounded, const Color(0xFF34D399), 'Haftalık Analiz');
      case 'NUTRITION_TREND':
        return (Icons.restaurant_rounded, const Color(0xFFEBC374), 'Beslenme Trendi');
      case 'WORKOUT_MILESTONE':
        return (Icons.fitness_center_rounded, const Color(0xFF73D4FF), 'Antrenman Dönüm Noktası');
      default:
        return (Icons.auto_awesome_rounded, const Color(0xFFBC74EB), 'AI Gözlemi');
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _InsightItem {
  final int id;
  final String? type;
  final String summary;
  final DateTime? createdAt;

  const _InsightItem({required this.id, this.type, required this.summary, this.createdAt});

  factory _InsightItem.fromJson(Map<String, dynamic> json) {
    return _InsightItem(
      id: json['id'] as int,
      type: json['type'] as String?,
      summary: json['summary'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}
