import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weekly_plan_provider.dart';

class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  static const _accent = Color(0xFF4ECDC4);

  // Form
  String _goal = 'Kas kazanımı';
  String _fitnessLevel = 'Orta';
  int _workoutsPerWeek = 4;
  final _focusController = TextEditingController(text: 'Göğüs, Sırt, Bacak, Omuz');
  final _injuriesController = TextEditingController();

  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    // init() is already called in app_providers.dart at startup — no need to repeat here
  }

  @override
  void dispose() {
    _focusController.dispose();
    _injuriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeeklyPlanProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            ),
            title: const Text(
              'Haftalık AI Plan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            actions: [
              if (provider.hasPlan)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: _accent),
                  onPressed: () => _showGenerateSheet(provider),
                  tooltip: 'Yeniden oluştur',
                ),
            ],
          ),
          body: provider.hasPlan
              ? _buildPlanView(provider)
              : _buildEmptyState(provider),
        );
      },
    );
  }

  Widget _buildEmptyState(WeeklyPlanProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _accent.withValues(alpha: 0.25),
                  _accent.withValues(alpha: 0.05),
                ]),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Haftalık Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sana özel 7 günlük antrenman programı oluşturulsun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading ? null : () => _showGenerateSheet(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                label: Text(
                  provider.isLoading ? 'Plan oluşturuluyor...' : 'Plan Oluştur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (provider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView(WeeklyPlanProvider provider) {
    final plan = provider.plan!;
    final today = DateTime.now().weekday - 1; // 0=Pzt

    return Column(
      children: [
        // ── Süresi dolmuş plan uyarısı ────────────────────────────────────
        if (provider.isExpired)
          GestureDetector(
            onTap: () => _showGenerateSheet(provider),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Planın süresi doldu. Yenilemek için dokun.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.orange, size: 18),
                ],
              ),
            ),
          ),

        // ── Özet banner ───────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent.withValues(alpha: 0.2), _accent.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Gün sekmeleri ──────────────────────────────────────────────────
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: plan.days.length,
            itemBuilder: (context, i) {
              final day = plan.days[i];
              final isSelected = i == _selectedDayIndex;
              final isToday = i == today;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? _accent
                          : isToday
                              ? Colors.white30
                              : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.dayName.substring(0, 3),
                        style: TextStyle(
                          color: isSelected ? _accent : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        day.isRestDay ? '😴' : '💪',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Seçili gün detayı ──────────────────────────────────────────────
        Expanded(
          child: _buildDayDetail(plan.days[_selectedDayIndex]),
        ),
      ],
    );
  }

  Widget _buildDayDetail(DayPlan day) {
    final color = day.isRestDay ? Colors.blue : _accent;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(
                  day.isRestDay ? '😴' : '💪',
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.dayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.focus,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Egzersizler
          Text(
            day.isRestDay ? 'Öneriler' : 'Egzersizler',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...day.exercises.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (day.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.notes,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGenerateSheet(WeeklyPlanProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Planı Kişiselleştir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 20),
                _label('Hedef'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Kas kazanımı', 'Yağ yakımı', 'Dayanıklılık', 'Genel form']
                      .map((g) => ChoiceChip(
                            label: Text(g),
                            selected: _goal == g,
                            onSelected: (_) => setSheetState(() => _goal = g),
                            selectedColor: _accent.withValues(alpha: 0.25),
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(
                              color: _goal == g ? _accent : Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: _goal == g
                                  ? _accent
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _label('Seviye'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Başlangıç', 'Orta', 'İleri']
                      .map((l) => ChoiceChip(
                            label: Text(l),
                            selected: _fitnessLevel == l,
                            onSelected: (_) => setSheetState(() => _fitnessLevel = l),
                            selectedColor: _accent.withValues(alpha: 0.25),
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(
                              color: _fitnessLevel == l ? _accent : Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: _fitnessLevel == l
                                  ? _accent
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _label('Haftalık antrenman: $_workoutsPerWeek gün'),
                Slider(
                  value: _workoutsPerWeek.toDouble(),
                  min: 2, max: 6, divisions: 4,
                  activeColor: _accent,
                  inactiveColor: Colors.white12,
                  onChanged: (v) => setSheetState(() => _workoutsPerWeek = v.round()),
                ),
                const SizedBox(height: 8),
                _label('Odak bölgeler (virgülle)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _focusController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Göğüs, Sırt, Bacak...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label('Sakatlık / kısıt (opsiyonel)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _injuriesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Örn: Sol diz ağrısı, omuz problemi...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      provider.generatePlan(
                        goal: _goal,
                        fitnessLevel: _fitnessLevel,
                        workoutsPerWeek: _workoutsPerWeek,
                        focusAreas: _focusController.text,
                        injuries: _injuriesController.text.isEmpty
                            ? null
                            : _injuriesController.text,
                        bodyWeight: null,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Planı Oluştur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );
}
