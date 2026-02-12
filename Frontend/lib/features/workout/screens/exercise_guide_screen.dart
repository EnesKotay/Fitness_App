import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/workout_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/workout_provider.dart';

/// Hareketin nasıl yapılacağını gösteren tam ekran sayfa.
/// Kullanıcı akışı: Liste → bu sayfa → "Gösterimi tamamladım" veya "Antrenmana ekle" → SnackBar + listeye dön.
class ExerciseGuideScreen extends StatelessWidget {
  final Exercise exercise;
  final Color accentColor;
  final String? muscleGroupLabel;

  const ExerciseGuideScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
    this.muscleGroupLabel,
  });

  /// Talimat metnini satırlara böl; numaralı liste veya paragraf olarak göster.
  static List<String> _instructionLines(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    return text
        .split(RegExp(r'[\n.]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _instructionLines(exercise.instructions);
    final hasDescription =
        exercise.description != null && exercise.description!.trim().isNotEmpty;
    final hasInstructions = lines.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nasıl yapılır?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
                  .copyWith(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hareket adı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bu hareket ne çalıştırır?
                  if (hasDescription) ...[
                    _SectionTitle(
                      label: 'Bu hareket ne çalıştırır?',
                      color: accentColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      exercise.description!.trim(),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Nasıl yapılır?
                  if (hasInstructions) ...[
                    _SectionTitle(
                      label: 'Nasıl yapılır?',
                      color: accentColor,
                    ),
                    const SizedBox(height: 12),
                    ...lines.asMap().entries.map((e) {
                      final i = e.key + 1;
                      final line = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (!hasDescription && !hasInstructions)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Bu hareket için henüz açıklama eklenmemiş.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Butonlar: Antrenmana ekle (giriş yapılmışsa) + Gösterimi tamamladım
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      final userId = authProvider.user?.id;
                      if (userId == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddToWorkoutSheet(context, userId),
                            icon: Icon(Icons.add_circle_outline, color: accentColor, size: 22),
                            label: const Text(
                              'Bu hareketi antrenmana ekle',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accentColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _onComplete(context),
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text(
                        'Gösterimi tamamladım',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onComplete(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: const Text(
          'Hareket gösterimi tamamlandı. Başka bir hareket seçmek için listeye dönün.',
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddToWorkoutSheet(BuildContext context, int userId) {
    final nameC = TextEditingController(text: exercise.name);
    final typeC = TextEditingController(text: muscleGroupLabel ?? exercise.muscleGroup);
    final durationC = TextEditingController();
    final notesC = TextEditingController(text: 'Hareket: ${exercise.name}');
    DateTime pickedDate = DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bu hareketi antrenmana ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameC,
                      decoration: _inputDeco('Antrenman adı'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: typeC,
                      decoration: _inputDeco('Tür (örn. Göğüs, Bacak)'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationC,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Süre (dk)'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Tarih: ${DateFormat('d MMM yyyy', 'tr_TR').format(pickedDate)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          pickedDate = d;
                          setSheetState(() {});
                        }
                      },
                    ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesC,
                  maxLines: 2,
                  decoration: _inputDeco('Not'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final request = WorkoutRequest(
                      name: nameC.text.trim().isEmpty ? null : nameC.text.trim(),
                      workoutType: typeC.text.trim().isEmpty ? null : typeC.text.trim(),
                      durationMinutes: int.tryParse(durationC.text.trim()),
                      caloriesBurned: null,
                      workoutDate: pickedDate,
                      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                    );
                    try {
                      final p = Provider.of<WorkoutProvider>(context, listen: false);
                      final ok = await p.createWorkout(userId, request);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      final messenger = ScaffoldMessenger.maybeOf(ctx);
                      if (ok) {
                        messenger?.showSnackBar(
                          const SnackBar(
                            content: Text('Antrenmana eklendi.'),
                            backgroundColor: Color(0xFF2E7D32),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text(p.errorMessage ?? 'Kaydedilemedi'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
