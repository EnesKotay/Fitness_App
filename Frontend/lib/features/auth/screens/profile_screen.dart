import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../shell/main_shell.dart';
import '../providers/auth_provider.dart';
import 'edit_profile_screen.dart';

const Color _warmAccent = Color(0xFFD89A6A);
const Color _freshGreen = Color(0xFF5FAE78);
const Color _softBlue = Color(0xFF7BA7D9);

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
      backgroundColor: const Color(0xFF070809),
      body: Consumer3<AuthProvider, DietProvider, WeightProvider>(
        builder: (context, authProvider, dietProvider, weightProvider, _) {
          final user = authProvider.user;
          final profile = dietProvider.profile;
          final name =
              profile?.name ??
              StorageHelper.getUserName() ??
              user?.name ??
              'Kullanıcı';
          final email = StorageHelper.getUserEmail() ?? user?.email ?? '';
          final targetKcal = dietProvider.dailyTargetKcal;
          final consumedKcal = dietProvider.totals.totalKcal;
          final remainingKcal = dietProvider.remainingKcal;
          final latestWeight =
              weightProvider.latestEntry?.weightKg ?? profile?.weight;
          final isToday = _isSameDay(dietProvider.selectedDate, DateTime.now());
          final dailyProgress = targetKcal != null && targetKcal > 0
              ? (consumedKcal / targetKcal).clamp(0.0, 1.0)
              : 0.0;
          final profileCompletion = _profileCompletion(profile, latestWeight);
          final missingFields = _missingProfileFields(
            profile,
            latestWeight,
            targetKcal,
          );
          final streakDays = _trackingStreakDays(weightProvider.entries);
          final compactViewport = MediaQuery.of(context).size.height < 760;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final textScaleExtra = ((textScale - 1.0) * 120).clamp(0.0, 64.0);
          final heroBaseHeight = compactViewport ? 420.0 : 368.0;
          final missingExtraHeight = missingFields.isNotEmpty
              ? (compactViewport ? 88.0 : 72.0)
              : 0.0;
          const heroSafetyPadding = 28.0;
          final heroHeight =
              heroBaseHeight +
              missingExtraHeight +
              textScaleExtra +
              heroSafetyPadding;
          final avatarSize = compactViewport ? 94.0 : 108.0;

          return Stack(
            children: [
              const _ProfileBackdrop(),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // —— Hero: Avatar + İsim + Hedef rozeti ——
                  SliverAppBar(
                    expandedHeight: heroHeight,
                    pinned: true,
                    scrolledUnderElevation: 0,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _glassPanel(
                              radius: 28,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                12,
                              ),
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.28,
                              ),
                              borderColor: Colors.white.withValues(alpha: 0.18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildAvatar(name, size: avatarSize),
                                  const SizedBox(height: 10),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.1,
                                        color: Colors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 7),
                                  _buildGoalChip(profile?.goal),
                                  const SizedBox(height: 10),
                                  _buildHeroKpiStrip(
                                    profileCompletion: profileCompletion,
                                    dailyProgress: dailyProgress,
                                    remainingKcal: remainingKcal,
                                    latestWeight: latestWeight,
                                    streakDays: streakDays,
                                    compact: compactViewport,
                                  ),
                                  if (missingFields.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _buildMissingProfilePanel(
                                      missingFields,
                                      compact: compactViewport,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // —— Bugünkü özet (kalbi) ——
                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 0,
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
                  ),

                  // —— Hızlı erişim: Antrenman, Takip, Beslenme ——
                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
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
                                    color: _warmAccent,
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
                                    color: _freshGreen,
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
                              color: _warmAccent,
                              tabIndex: 3,
                              fullWidth: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('PROFIL BILGILERI'),
                            _buildProfileDetailsCard(
                              profile: profile,
                              latestWeight: latestWeight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // —— Özet istatistikler ——
                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 3,
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
                                  latestWeight != null
                                      ? '${latestWeight.toStringAsFixed(1)} kg'
                                      : '--',
                                  Icons.monitor_weight_outlined,
                                  _softBlue,
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  'Hedef',
                                  targetKcal != null
                                      ? '${targetKcal.round()} kcal'
                                      : '--',
                                  Icons.local_fire_department_outlined,
                                  _warmAccent,
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  'BMI',
                                  _bmiString(profile),
                                  Icons.accessibility_new_outlined,
                                  _freshGreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // —— Profili düzenle ——
                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditProfile(context),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: _warmAccent,
                            ),
                            label: const Text('Profili Düzenle'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.03,
                              ),
                              side: BorderSide(
                                color: _warmAccent.withValues(alpha: 0.42),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // —— Ayarlar ——
                  SliverToBoxAdapter(
                    child: _buildEntrance(
                      order: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('HESAP & AYARLAR'),
                            _settingsTile(
                              icon: Icons.lock_outline_rounded,
                              accent: _warmAccent,
                              title: 'Şifre Değiştir',
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.notifications_none_rounded,
                              accent: _softBlue,
                              title: 'Bildirimler',
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.palette_outlined,
                              accent: _freshGreen,
                              title: 'Tema & Görünüm',
                              subtitle: 'Koyu Mod',
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.help_outline_rounded,
                              accent: _warmAccent,
                              title: 'Yardım',
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.privacy_tip_outlined,
                              accent: _softBlue,
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
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EditProfileScreen()));
  }

  Widget _buildEntrance({required int order, required Widget child}) {
    final start = (order * 0.08).clamp(0.0, 0.55).toDouble();
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 760),
      tween: Tween(begin: 0, end: 1),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final dy = (1 - value) * 18;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }

  Widget _buildAvatar(String fullName, {double size = 108}) {
    final initials = _initialsFromName(fullName);
    final avatarTextSize = size * 0.315;
    final indicatorSize = (size * 0.15).clamp(14.0, 18.0);
    final indicatorBorder = (size * 0.018).clamp(1.8, 2.4);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _warmAccent.withValues(alpha: 0.98),
                const Color(0xFFFFB88D).withValues(alpha: 0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _warmAccent.withValues(alpha: 0.34),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF171A20), Color(0xFF111318)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: avatarTextSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        Positioned(
          right: size * 0.037,
          bottom: size * 0.055,
          child: Container(
            width: indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              color: _freshGreen,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0F1215),
                width: indicatorBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalChip(Goal? goal) {
    String text;
    Color color;
    switch (goal) {
      case Goal.loseWeight:
        text = 'Hedef: Kilo ver';
        color = _warmAccent;
        break;
      case Goal.gainWeight:
        text = 'Hedef: Kilo al';
        color = _softBlue;
        break;
      case Goal.maintainWeight:
      default:
        text = 'Hedef: Kiloyu koru';
        color = _freshGreen;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _heroMetricPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroKpiStrip({
    required double profileCompletion,
    required double dailyProgress,
    required double remainingKcal,
    required double? latestWeight,
    required int streakDays,
    required bool compact,
  }) {
    final remaining = remainingKcal.round();
    final weightText = latestWeight != null
        ? '${latestWeight.toStringAsFixed(1)} kg'
        : '--';
    final compactWeightText = latestWeight != null
        ? '${latestWeight.toStringAsFixed(1)}kg'
        : '--';
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _heroMetricPill(
              icon: Icons.person_outline_rounded,
              label: 'Profil',
              value: '%${(profileCompletion * 100).round()}',
            ),
            _heroMetricPill(
              icon: Icons.local_fire_department_rounded,
              label: 'Gunluk',
              value: '%${(dailyProgress * 100).round()}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (compact)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _heroMetricPill(
                icon: Icons.bolt_rounded,
                label: 'Kalan',
                value: '${remaining}kcal',
              ),
              _heroMetricPill(
                icon: Icons.monitor_weight_outlined,
                label: 'Kilo',
                value: compactWeightText,
              ),
              _heroMetricPill(
                icon: Icons.whatshot_rounded,
                label: 'Seri',
                value: '$streakDays gun',
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _heroKpiCard(
                  icon: Icons.bolt_rounded,
                  label: 'Kalan',
                  value: '$remaining kcal',
                  tone: _warmAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroKpiCard(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Kilo',
                  value: weightText,
                  tone: _softBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroKpiCard(
                  icon: Icons.whatshot_rounded,
                  label: 'Seri',
                  value: '$streakDays gun',
                  tone: _freshGreen,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _heroKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: tone),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingProfilePanel(
    List<({String label, IconData icon})> missingFields, {
    bool compact = false,
  }) {
    final shownFields = missingFields
        .take(compact ? 2 : 4)
        .toList(growable: false);
    final extraCount = missingFields.length - shownFields.length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, 8, 10, compact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warmAccent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: _warmAccent.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Eksik profil alanlari',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openEditProfile(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _warmAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _warmAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Duzenle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (compact)
            Text(
              'Tamamlanmayan: ${missingFields.length} alan',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final field in shownFields)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          field.icon,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          field.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (extraCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      '+$extraCount alan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double radius = 16,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final panelRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: panelRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.055),
            borderRadius: panelRadius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: child,
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
    final consumedText = consumedKcal.round().toString();
    final targetText = target.round().toString();
    final remainingText = remainingKcal.round().toString();

    return _glassPanel(
      radius: 22,
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.black.withValues(alpha: 0.30),
      borderColor: Colors.white.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Bugunku ozet' : 'Gunluk ozet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.8,
                ),
              ),
              _progressBadge(progress),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    consumedText,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '/ $targetText kcal',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_warmAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kalan: $remainingText kcal',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniMetaPill(
                icon: Icons.flag_outlined,
                text: 'Hedef $targetText',
              ),
              _miniMetaPill(
                icon: Icons.check_circle_outline_rounded,
                text: 'Alinan $consumedText',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetaPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBadge(double progress) {
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _warmAccent.withValues(alpha: 0.28),
            _warmAccent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _warmAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: _warmAccent,
          ),
          const SizedBox(width: 4),
          Text(
            '%$percent',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard({
    required UserProfile? profile,
    required double? latestWeight,
  }) {
    return _glassPanel(
      radius: 16,
      padding: const EdgeInsets.all(16),
      backgroundColor: Colors.black.withValues(alpha: 0.28),
      borderColor: Colors.white.withValues(alpha: 0.14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _warmAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: _warmAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Temel Profil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Canli',
                style: TextStyle(
                  color: _freshGreen.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.cake_outlined,
                  label: 'Yas',
                  value: profile != null ? '${profile.age}' : '--',
                  tone: _warmAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.height_rounded,
                  label: 'Boy',
                  value: profile != null
                      ? '${profile.height.toStringAsFixed(0)} cm'
                      : '--',
                  tone: _softBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Kilo',
                  value: latestWeight != null
                      ? '${latestWeight.toStringAsFixed(1)} kg'
                      : '--',
                  tone: _freshGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.flag_outlined,
                  label: 'Hedef',
                  value: _goalLabel(profile?.goal),
                  tone: _warmAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.wc_rounded,
                  label: 'Cinsiyet',
                  value: _genderLabel(profile?.gender),
                  tone: _softBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _profileInfoTile(
                  icon: Icons.directions_run_rounded,
                  label: 'Aktivite',
                  value: _activityLabel(profile?.activityLevel),
                  tone: _freshGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.12), tone.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tone),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          MainShell.tabSwitchRequest.value = tabIndex;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(tabIndex);
          } else {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: _glassPanel(
          radius: 16,
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.black.withValues(alpha: 0.26),
          borderColor: color.withValues(alpha: 0.35),
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
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: _glassPanel(
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        backgroundColor: Colors.black.withValues(alpha: 0.25),
        borderColor: color.withValues(alpha: 0.24),
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
    required Color accent,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: _glassPanel(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            backgroundColor: Colors.black.withValues(alpha: 0.24),
            borderColor: Colors.white.withValues(alpha: 0.12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutTile(BuildContext context, AuthProvider authProvider) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _confirmLogout(authProvider),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withValues(alpha: 0.2),
                Colors.red.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade300, size: 20),
              const SizedBox(width: 10),
              Text(
                'Cikis Yap',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _goalLabel(Goal? goal) {
    switch (goal) {
      case Goal.loseWeight:
        return 'Kilo Ver';
      case Goal.gainWeight:
        return 'Kilo Al';
      case Goal.maintainWeight:
        return 'Koru';
      default:
        return '--';
    }
  }

  String _genderLabel(Gender? gender) {
    switch (gender) {
      case Gender.male:
        return 'Erkek';
      case Gender.female:
        return 'Kadin';
      default:
        return '--';
    }
  }

  String _activityLabel(ActivityLevel? level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Dusuk';
      case ActivityLevel.lightlyActive:
        return 'Hafif';
      case ActivityLevel.moderatelyActive:
        return 'Orta';
      case ActivityLevel.veryActive:
        return 'Yuksek';
      case ActivityLevel.extraActive:
        return 'Cok Yuksek';
      default:
        return '--';
    }
  }

  List<({String label, IconData icon})> _missingProfileFields(
    UserProfile? profile,
    double? latestWeight,
    double? targetKcal,
  ) {
    if (profile == null) {
      return const [
        (label: 'Ad', icon: Icons.badge_outlined),
        (label: 'Yas', icon: Icons.cake_outlined),
        (label: 'Boy', icon: Icons.height_rounded),
        (label: 'Kilo', icon: Icons.monitor_weight_outlined),
        (label: 'Hedef', icon: Icons.flag_outlined),
      ];
    }

    final fields = <({String label, IconData icon})>[];
    if (profile.name.trim().isEmpty) {
      fields.add((label: 'Ad', icon: Icons.badge_outlined));
    }
    if (profile.age <= 0) {
      fields.add((label: 'Yas', icon: Icons.cake_outlined));
    }
    if (profile.height <= 0) {
      fields.add((label: 'Boy', icon: Icons.height_rounded));
    }
    if ((latestWeight ?? profile.weight) <= 0) {
      fields.add((label: 'Kilo', icon: Icons.monitor_weight_outlined));
    }
    if ((profile.targetWeight ?? 0) <= 0) {
      fields.add((label: 'Hedef kilo', icon: Icons.flag_outlined));
    }
    if ((targetKcal ?? 0) <= 0) {
      fields.add((
        label: 'Kalori hedefi',
        icon: Icons.local_fire_department_outlined,
      ));
    }
    return fields;
  }

  double _profileCompletion(UserProfile? profile, double? latestWeight) {
    if (profile == null) return 0;
    var filled = 0;
    if (profile.name.trim().isNotEmpty) filled++;
    if (profile.age > 0) filled++;
    if (profile.height > 0) filled++;
    if ((latestWeight ?? 0) > 0) filled++;
    if ((profile.targetWeight ?? 0) > 0) filled++;
    if ((profile.customKcalTarget ?? 0) > 0) filled++;
    return (filled / 6).clamp(0.0, 1.0);
  }

  int _trackingStreakDays(List<WeightEntry> entries) {
    if (entries.isEmpty) return 0;

    final uniqueDays =
        entries
            .map(
              (entry) =>
                  DateTime(entry.date.year, entry.date.month, entry.date.day),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (uniqueDays.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var index = 0;

    if (!_isSameDay(uniqueDays.first, cursor)) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (!_isSameDay(uniqueDays.first, yesterday)) {
        return 0;
      }
      cursor = yesterday;
    }

    var streak = 0;
    while (index < uniqueDays.length && _isSameDay(uniqueDays[index], cursor)) {
      streak++;
      index++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _initialsFromName(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
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

  Future<void> _confirmLogout(AuthProvider authProvider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cikis yap?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Hesabinizdan cikis yapmak istediginize emin misiniz?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Iptal',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cikis Yap',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final oldSuffix = StorageHelper.getUserStorageSuffix();
    final dietProvider = context.read<DietProvider>();
    final weightProvider = context.read<WeightProvider>();

    dietProvider.reset();
    weightProvider.reset();

    await authProvider.logout();
    await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
    await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);

    if (!mounted) return;

    await dietProvider.init();
    await weightProvider.loadEntries();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ChatGPT Image 14 Şub 2026 07_28_10.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x30000000),
                    Color(0x70000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.85),
                  radius: 1.1,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0x55000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
