import 'package:flutter/material.dart';
import '../../../core/services/meal_reminder_service.dart';
import '../../../core/services/water_reminder_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/notification_scheduler_service.dart';
import '../../../core/utils/storage_helper.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {
  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFCC7A4A);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9E9E9E);

  bool _enabled = true;
  bool _water = true;
  bool _workout = true;
  bool _dailySummary = true;
  int _waterIntervalHours = 2;
  bool _loading = true;

  // Meal reminder state
  bool _mealEnabled = false;
  bool _breakfastEnabled = true;
  bool _lunchEnabled = true;
  bool _dinnerEnabled = true;
  bool _snackEnabled = true;
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _snackTime = const TimeOfDay(hour: 16, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _enabled = StorageHelper.getNotifEnabled();
    _water = StorageHelper.getNotifWater();
    _workout = StorageHelper.getNotifWorkout();
    _dailySummary = StorageHelper.getNotifDailySummary();
    _waterIntervalHours = await WaterReminderService.instance
        .getIntervalHours();

    final mealSettings = await MealReminderService.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _mealEnabled = mealSettings.enabled;
      _breakfastEnabled = mealSettings.breakfastEnabled;
      _lunchEnabled = mealSettings.lunchEnabled;
      _dinnerEnabled = mealSettings.dinnerEnabled;
      _snackEnabled = mealSettings.snackEnabled;

      _breakfastTime = mealSettings.breakfastTime;
      _lunchTime = mealSettings.lunchTime;
      _dinnerTime = mealSettings.dinnerTime;
      _snackTime = mealSettings.snackTime;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await StorageHelper.saveNotifEnabled(_enabled);
    await StorageHelper.saveNotifWater(_water);
    await StorageHelper.saveNotifWorkout(_workout);
    await StorageHelper.saveNotifDailySummary(_dailySummary);
    await WaterReminderService.instance.setEnabled(_water);
    await WaterReminderService.instance.setIntervalHours(_waterIntervalHours);
    await NotificationSchedulerService.instance.syncScheduledNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirim ayarları kaydedildi'),
        backgroundColor: Color(0xFF388E3C),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _persistMeal() async {
    await MealReminderService.instance.setEnabled(_mealEnabled);
    await MealReminderService.instance.setMealEnabled(
      'breakfast',
      _breakfastEnabled,
    );
    await MealReminderService.instance.setMealEnabled('lunch', _lunchEnabled);
    await MealReminderService.instance.setMealEnabled('dinner', _dinnerEnabled);
    await MealReminderService.instance.setMealEnabled('snack', _snackEnabled);

    await MealReminderService.instance.setMealTime('breakfast', _breakfastTime);
    await MealReminderService.instance.setMealTime('lunch', _lunchTime);
    await MealReminderService.instance.setMealTime('dinner', _dinnerTime);
    await MealReminderService.instance.setMealTime('snack', _snackTime);
    await NotificationSchedulerService.instance.syncScheduledNotifications();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Öğün hatırlatıcı ayarları güncellendi'),
        backgroundColor: Color(0xFF388E3C),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _pickMealTime(String meal) async {
    TimeOfDay initial;
    switch (meal) {
      case 'breakfast':
        initial = _breakfastTime;
        break;
      case 'lunch':
        initial = _lunchTime;
        break;
      case 'dinner':
        initial = _dinnerTime;
        break;
      default:
        initial = _snackTime;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              onPrimary: Colors.white,
              surface: _card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      switch (meal) {
        case 'breakfast':
          _breakfastTime = picked;
          break;
        case 'lunch':
          _lunchTime = picked;
          break;
        case 'dinner':
          _dinnerTime = picked;
          break;
        default:
          _snackTime = picked;
      }
    });
    await _persistMeal();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Bildirimler',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard([
            _prefTile(
              icon: Icons.notifications_active_rounded,
              iconColor: _accent,
              title: 'Bildirimleri Etkinleştir',
              subtitle: 'Uygulama bildirimlerini genel olarak aç/kapat',
              value: _enabled,
              onChanged: (v) async {
                if (v) {
                  final granted = await LocalNotificationService.instance
                      .requestPermission();
                  if (!granted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cihaz ayarlarından bildirim izni vermelisiniz.',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                }
                setState(() => _enabled = v);
                await _persist();
                if (!_enabled) {
                  await LocalNotificationService.instance.cancelAll();
                }
              },
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader('GENEL'),
          _buildCard([
            _prefTile(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF42A5F5),
              title: 'Su Hatırlatıcıları',
              subtitle: 'Gün içinde su içme hatırlatması',
              value: _water,
              enabled: _enabled,
              onChanged: (v) async {
                setState(() => _water = v);
                await _persist();
              },
            ),
            if (_water && _enabled) ...[
              _divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hatırlatma Aralığı',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Her $_waterIntervalHours saatte bir',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: _accent,
                        inactiveTrackColor: _accent.withValues(alpha: 0.2),
                        thumbColor: _accent,
                        overlayColor: _accent.withValues(alpha: 0.1),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _waterIntervalHours.toDouble(),
                        min: 1,
                        max: 6,
                        divisions: 5,
                        onChanged: (v) =>
                            setState(() => _waterIntervalHours = v.round()),
                        onChangeEnd: (_) async => _persist(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _divider(),
            _prefTile(
              icon: Icons.fitness_center_rounded,
              iconColor: const Color(0xFFEF5350),
              title: 'Antrenman Hatırlatmaları',
              subtitle: 'Planlı antrenmanlar için hatırlatma',
              value: _workout,
              enabled: _enabled,
              onChanged: (v) async {
                setState(() => _workout = v);
                await _persist();
              },
            ),
            _divider(),
            _prefTile(
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFFAB47BC),
              title: 'Gün Sonu Özeti',
              subtitle: 'Kalori ve ilerleme özet bildirimi',
              value: _dailySummary,
              enabled: _enabled,
              onChanged: (v) async {
                setState(() => _dailySummary = v);
                await _persist();
              },
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeader('ÖĞÜN HATIRLATICILARI'),
          _buildCard([
            _prefTile(
              icon: Icons.restaurant_menu_rounded,
              iconColor: const Color(0xFF4CAF50),
              title: 'Öğünleri Hatırlat',
              subtitle: 'Beslenme programına sadık kalman için hatırlatmalar',
              value: _mealEnabled,
              enabled: _enabled,
              onChanged: (v) async {
                setState(() => _mealEnabled = v);
                await _persistMeal();
              },
            ),
            if (_mealEnabled && _enabled) ...[
              _divider(),
              _mealTimeTile(
                title: 'Kahvaltı',
                enabled: _breakfastEnabled,
                time: _breakfastTime,
                onToggle: (v) async {
                  setState(() => _breakfastEnabled = v);
                  await _persistMeal();
                },
                onTimeTap: () => _pickMealTime('breakfast'),
              ),
              _divider(),
              _mealTimeTile(
                title: 'Öğle Yemeği',
                enabled: _lunchEnabled,
                time: _lunchTime,
                onToggle: (v) async {
                  setState(() => _lunchEnabled = v);
                  await _persistMeal();
                },
                onTimeTap: () => _pickMealTime('lunch'),
              ),
              _divider(),
              _mealTimeTile(
                title: 'Akşam Yemeği',
                enabled: _dinnerEnabled,
                time: _dinnerTime,
                onToggle: (v) async {
                  setState(() => _dinnerEnabled = v);
                  await _persistMeal();
                },
                onTimeTap: () => _pickMealTime('dinner'),
              ),
              _divider(),
              _mealTimeTile(
                title: 'Atıştırmalık',
                enabled: _snackEnabled,
                time: _snackTime,
                onToggle: (v) async {
                  setState(() => _snackEnabled = v);
                  await _persistMeal();
                },
                onTimeTap: () => _pickMealTime('snack'),
              ),
            ],
          ]),
          const SizedBox(height: 40),
        ],
      ),
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
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? iconColor.withValues(alpha: 0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? iconColor : Colors.white38,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? _textPrimary : Colors.white38,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? _textSecondary : Colors.white24,
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: _accent,
        activeTrackColor: _accent.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.white12,
      ),
    );
  }

  Widget _mealTimeTile({
    required String title,
    required bool enabled,
    required TimeOfDay time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTimeTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: enabled ? _textPrimary : Colors.white38,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          if (enabled)
            GestureDetector(
              onTap: onTimeTap,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(time),
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_rounded,
                      color: _textSecondary,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: _accent,
            activeTrackColor: _accent.withValues(alpha: 0.5),
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Colors.white10,
  );
}
