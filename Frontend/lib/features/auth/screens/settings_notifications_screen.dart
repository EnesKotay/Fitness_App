import 'package:flutter/material.dart';
import '../../../core/services/meal_reminder_service.dart';
import '../../../core/services/water_reminder_service.dart';
import '../../../core/utils/storage_helper.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {
  bool _enabled = true;
  bool _water = true;
  bool _workout = true;
  bool _dailySummary = true;
  int _waterIntervalHours = 2;
  bool _loading = true;

  // Meal reminder state
  bool _mealEnabled = false;
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
    _waterIntervalHours = await WaterReminderService.instance.getIntervalHours();

    final mealSettings = await MealReminderService.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _mealEnabled = mealSettings.enabled;
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
    await WaterReminderService.instance.setEnabled(_enabled && _water);
    await WaterReminderService.instance.setIntervalHours(_waterIntervalHours);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirim ayarlari kaydedildi.'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _persistMeal() async {
    await MealReminderService.instance.setEnabled(_mealEnabled);
    await MealReminderService.instance.setMealTime('breakfast', _breakfastTime);
    await MealReminderService.instance.setMealTime('lunch', _lunchTime);
    await MealReminderService.instance.setMealTime('dinner', _dinnerTime);
    await MealReminderService.instance.setMealTime('snack', _snackTime);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Öğün hatırlatıcı ayarları kaydedildi.'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _enabled = true;
      _water = true;
      _workout = true;
      _dailySummary = true;
      _waterIntervalHours = 2;
    });
    await _persist();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            onChanged: (v) async {
              setState(() => _enabled = v);
              await _persist();
            },
            title: const Text('Bildirimleri etkinlestir'),
            subtitle: const Text(
              'Uygulama bildirimlerini genel olarak ac/kapat',
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _water,
            onChanged: _enabled
                ? (v) async {
                    setState(() => _water = v);
                    await _persist();
                  }
                : null,
            title: const Text('Su hatirlaticilari'),
            subtitle: const Text('Gun icinde su icme hatirlatmasi'),
          ),
          ListTile(
            enabled: _enabled && _water,
            title: const Text('Su hatirlatma araligi'),
            subtitle: Text('Her $_waterIntervalHours saatte bir'),
          ),
          Slider(
            value: _waterIntervalHours.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            label: '$_waterIntervalHours saat',
            onChanged: (_enabled && _water)
                ? (v) => setState(() => _waterIntervalHours = v.round())
                : null,
            onChangeEnd: (_enabled && _water) ? (_) async => _persist() : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _workout,
            onChanged: _enabled
                ? (v) async {
                    setState(() => _workout = v);
                    await _persist();
                  }
                : null,
            title: const Text('Antrenman hatirlatmalari'),
            subtitle: const Text('Planli antrenmanlar icin hatirlatma'),
          ),
          SwitchListTile(
            value: _dailySummary,
            onChanged: _enabled
                ? (v) async {
                    setState(() => _dailySummary = v);
                    await _persist();
                  }
                : null,
            title: const Text('Gun sonu ozeti'),
            subtitle: const Text('Kalori ve ilerleme ozet bildirimi'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Varsayilanlara Don'),
          ),

          // ── Öğün Hatırlatıcıları ──────────────────────────────────────
          const SizedBox(height: 24),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Öğün Hatırlatıcıları',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          SwitchListTile(
            value: _mealEnabled,
            onChanged: _enabled
                ? (v) async {
                    setState(() => _mealEnabled = v);
                    await _persistMeal();
                  }
                : null,
            title: const Text('Öğün hatırlatıcılarını etkinleştir'),
            subtitle: const Text('Her öğün için belirlenen saatte hatırlat'),
          ),
          if (_mealEnabled && _enabled) ...[
            const Divider(height: 1),
            ListTile(
              title: const Text('Kahvaltı'),
              subtitle: Text(_formatTime(_breakfastTime)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: () => _pickMealTime('breakfast'),
            ),
            ListTile(
              title: const Text('Öğle'),
              subtitle: Text(_formatTime(_lunchTime)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: () => _pickMealTime('lunch'),
            ),
            ListTile(
              title: const Text('Akşam'),
              subtitle: Text(_formatTime(_dinnerTime)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: () => _pickMealTime('dinner'),
            ),
            ListTile(
              title: const Text('Atıştırma'),
              subtitle: Text(_formatTime(_snackTime)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: () => _pickMealTime('snack'),
            ),
          ],
        ],
      ),
    );
  }
}
