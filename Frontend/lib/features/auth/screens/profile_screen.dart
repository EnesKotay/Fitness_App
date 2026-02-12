import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../providers/auth_provider.dart';
import 'edit_profile_screen.dart';

/// Uygulamanın kalbi: Özet, hızlı erişim, hedef ve ayarlar tek yerde.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DietProvider>().loadDay(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Consumer3<AuthProvider, DietProvider, WeightProvider>(
        builder: (context, authProvider, dietProvider, weightProvider, _) {
          final user = authProvider.user;
          final profile = dietProvider.profile;
          final name = profile?.name ?? StorageHelper.getUserName() ?? user?.name ?? 'Kullanıcı';
          final email = StorageHelper.getUserEmail() ?? user?.email ?? '';
          final targetKcal = dietProvider.dailyTargetKcal;
          final consumedKcal = dietProvider.totals.totalKcal;
          final remainingKcal = dietProvider.remainingKcal;
          final latestWeight = weightProvider.latestEntry?.weightKg ?? profile?.weight;
          final isToday = _isSameDay(dietProvider.selectedDate, DateTime.now());

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // —— Hero: Avatar + İsim + Hedef rozeti ——
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: const Color(0xFF0A0A0A),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFCC7A4A).withValues(alpha: 0.2),
                          const Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          _buildAvatar(),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          _buildGoalChip(profile?.goal),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // —— Bugünkü özet (kalbi) ——
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _buildTodayCard(
                    targetKcal: targetKcal,
                    consumedKcal: consumedKcal,
                    remainingKcal: remainingKcal,
                    isToday: isToday,
                  ),
                ),
              ),

              // —— Hızlı erişim: Antrenman, Takip, Beslenme ——
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('SENİN ALANIN'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _quickAccessCard(
                              context,
                              icon: Icons.fitness_center_rounded,
                              label: 'Antrenman',
                              subtitle: 'Antrenmana başla',
                              color: const Color(0xFFCC7A4A),
                              tabIndex: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _quickAccessCard(
                              context,
                              icon: Icons.trending_up_rounded,
                              label: 'Kilo Takibi',
                              subtitle: 'Grafik & geçmiş',
                              color: const Color(0xFF4CAF50),
                              tabIndex: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _quickAccessCard(
                        context,
                        icon: Icons.restaurant_rounded,
                        label: 'Beslenme',
                        subtitle: 'Kalori & öğünler',
                        color: const Color(0xFFFF9800),
                        tabIndex: 3,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),

              // —— Özet istatistikler ——
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('ÖZET'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard(
                            'Kilo',
                            latestWeight != null ? '${latestWeight.toStringAsFixed(1)} kg' : '--',
                            Icons.monitor_weight_outlined,
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Hedef',
                            targetKcal != null ? '${targetKcal.round()} kcal' : '--',
                            Icons.local_fire_department_outlined,
                            const Color(0xFFCC7A4A),
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'BMI',
                            _bmiString(profile),
                            Icons.accessibility_new_outlined,
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // —— Profili düzenle ——
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Profili Düzenle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // —— Ayarlar ——
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('HESAP & AYARLAR'),
                      _settingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Şifre Değiştir',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Bildirimler',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.palette_outlined,
                        title: 'Tema & Görünüm',
                        subtitle: 'Koyu Mod',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Yardım',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Gizlilik',
                        onTap: () {},
                      ),
                      const SizedBox(height: 24),
                      _logoutTile(context, authProvider),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFCC7A4A).withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC7A4A).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 44,
        color: Color(0xFFCC7A4A),
      ),
    );
  }

  Widget _buildGoalChip(Goal? goal) {
    String text;
    Color color;
    switch (goal) {
      case Goal.loseWeight:
        text = 'Hedef: Kilo ver';
        color = Colors.orange;
        break;
      case Goal.gainWeight:
        text = 'Hedef: Kilo al';
        color = Colors.blue;
        break;
      case Goal.maintainWeight:
      default:
        text = 'Hedef: Kiloyu koru';
        color = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTodayCard({
    required double? targetKcal,
    required double consumedKcal,
    required double remainingKcal,
    required bool isToday,
  }) {
    final target = targetKcal ?? 2000.0;
    final progress = target > 0 ? (consumedKcal / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFCC7A4A).withValues(alpha: 0.15),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Bugünkü özet' : 'Günlük özet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: const Color(0xFFCC7A4A).withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${consumedKcal.round()}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '/ ${target.round()} kcal',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCC7A4A)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kalan: ${remainingKcal.round()} kcal',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _quickAccessCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required int tabIndex,
    bool fullWidth = false,
  }) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop(tabIndex);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: fullWidth
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutTile(BuildContext context, AuthProvider authProvider) {
    return Material(
      color: Colors.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _confirmLogout(context, authProvider),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 10),
              Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _bmiString(UserProfile? p) {
    if (p == null || p.height <= 0) return '--';
    final h = p.height / 100;
    final bmi = p.weight / (h * h);
    return bmi.toStringAsFixed(1);
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider authProvider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış yap?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      // 1) Çıkıştan önce eski suffix; logout sonrası bu box'lar kapatılacak
      final oldSuffix = StorageHelper.getUserStorageSuffix();
      // 2) Bellekteki state temizle
      context.read<DietProvider>().reset();
      context.read<WeightProvider>().reset();
      // 3) Auth + token + userId cache temizle
      await authProvider.logout();
      // 4) Eski kullanıcının Hive box'larını kapat
      await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
      await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);
      debugPrint('Logout: switchUser -> guest (closed $oldSuffix)');
      // 5) Guest ile init/loadEntries
      if (context.mounted) {
        await context.read<DietProvider>().init();
        await context.read<WeightProvider>().loadEntries();
      }
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
}
