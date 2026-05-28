import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/models/body_measurement.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tracking_provider.dart';

/// Premium step-by-step measurement entry sheet.
/// Groups body regions into logical steps so the form feels manageable.
class AddMeasurementSheet extends StatefulWidget {
  final BodyMeasurement? existingMeasurement;
  const AddMeasurementSheet({super.key, this.existingMeasurement});

  @override
  State<AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<AddMeasurementSheet> {
  // ── State ──────────────────────────────────────────────────────────────────
  late DateTime _selectedDate;
  int _step = 0; // 0 = üst gövde, 1 = alt gövde, 2 = özet
  bool _isSaving = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _chestCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipsCtrl;
  late final TextEditingController _leftArmCtrl;
  late final TextEditingController _rightArmCtrl;
  late final TextEditingController _leftLegCtrl;
  late final TextEditingController _rightLegCtrl;

  bool get _isEditMode => widget.existingMeasurement != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingMeasurement;
    _selectedDate = e?.date ?? DateTime.now();
    _chestCtrl    = TextEditingController(text: e?.chest?.toStringAsFixed(1)    ?? '');
    _waistCtrl    = TextEditingController(text: e?.waist?.toStringAsFixed(1)    ?? '');
    _hipsCtrl     = TextEditingController(text: e?.hips?.toStringAsFixed(1)     ?? '');
    _leftArmCtrl  = TextEditingController(text: e?.leftArm?.toStringAsFixed(1)  ?? '');
    _rightArmCtrl = TextEditingController(text: e?.rightArm?.toStringAsFixed(1) ?? '');
    _leftLegCtrl  = TextEditingController(text: e?.leftLeg?.toStringAsFixed(1)  ?? '');
    _rightLegCtrl = TextEditingController(text: e?.rightLeg?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _chestCtrl, _waistCtrl, _hipsCtrl,
      _leftArmCtrl, _rightArmCtrl, _leftLegCtrl, _rightLegCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool get _hasAnyValue => [
    _chestCtrl, _waistCtrl, _hipsCtrl,
    _leftArmCtrl, _rightArmCtrl, _leftLegCtrl, _rightLegCtrl,
  ].any((c) => double.tryParse(c.text.replaceAll(',', '.')) != null);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // ── Header ─────────────────────────────────────────────────────
          Text(
            _isEditMode ? 'Ölçüleri Düzenle' : 'Mezura Ölçüleri',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isEditMode
                ? 'Ölçümleri düzenleyip kaydet'
                : 'İstediğin bölgeleri doldur, hepsini girmen şart değil',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),

          const SizedBox(height: 20),

          // ── Date picker ────────────────────────────────────────────────
          _DatePickerRow(
            date: _selectedDate,
            onChanged: (d) => setState(() => _selectedDate = d),
          ),

          const SizedBox(height: 20),

          // ── Stepper indicator ─────────────────────────────────────────
          if (!_isEditMode) ...[
            _StepIndicator(currentStep: _step, totalSteps: 2),
            const SizedBox(height: 20),
          ],

          // ── Form content ───────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              child: _isEditMode
                  ? _AllFieldsSection(
                      chestCtrl:    _chestCtrl,
                      waistCtrl:    _waistCtrl,
                      hipsCtrl:     _hipsCtrl,
                      leftArmCtrl:  _leftArmCtrl,
                      rightArmCtrl: _rightArmCtrl,
                      leftLegCtrl:  _leftLegCtrl,
                      rightLegCtrl: _rightLegCtrl,
                    )
                  : _step == 0
                      ? _UpperBodySection(
                          chestCtrl:    _chestCtrl,
                          waistCtrl:    _waistCtrl,
                          hipsCtrl:     _hipsCtrl,
                          leftArmCtrl:  _leftArmCtrl,
                          rightArmCtrl: _rightArmCtrl,
                        )
                      : _LowerBodySection(
                          leftLegCtrl:  _leftLegCtrl,
                          rightLegCtrl: _rightLegCtrl,
                        ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Action buttons ─────────────────────────────────────────────
          if (_isEditMode)
            _SaveButton(
              label: 'Güncelle',
              isSaving: _isSaving,
              onTap: _save,
            )
          else
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    flex: 1,
                    child: _OutlineButton(
                      label: 'Geri',
                      onTap: () => setState(() => _step--),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: _step == 0
                      ? _NextButton(onTap: () => setState(() => _step = 1))
                      : _SaveButton(
                          label: 'Kaydet',
                          isSaving: _isSaving,
                          onTap: _save,
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;

    final parse = (TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));

    if (!_hasAnyValue) {
      AppSnack.showError(context, 'En az bir ölçü girmelisin.');
      return;
    }

    final vals = <String, double?>{
      'Göğüs':     parse(_chestCtrl),
      'Bel':       parse(_waistCtrl),
      'Kalça':     parse(_hipsCtrl),
      'Sol Kol':   parse(_leftArmCtrl),
      'Sağ Kol':   parse(_rightArmCtrl),
      'Sol Bacak': parse(_leftLegCtrl),
      'Sağ Bacak': parse(_rightLegCtrl),
    };

    for (final e in vals.entries) {
      final v = e.value;
      if (v != null && (v <= 0 || v > 300)) {
        AppSnack.showError(context, '${e.key} için geçerli bir değer girin (1–300 cm).');
        return;
      }
    }

    final req = BodyMeasurementRequest(
      date:      _selectedDate,
      chest:     vals['Göğüs'],
      waist:     vals['Bel'],
      hips:      vals['Kalça'],
      leftArm:   vals['Sol Kol'],
      rightArm:  vals['Sağ Kol'],
      leftLeg:   vals['Sol Bacak'],
      rightLeg:  vals['Sağ Bacak'],
    );

    final provider = context.read<TrackingProvider>();
    final authId   = context.read<AuthProvider>().user?.id;
    if (authId == null || authId <= 0) {
      AppSnack.showError(context, 'Kullanıcı oturumu bulunamadı.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final ok = _isEditMode
        ? await provider.updateBodyMeasurement(
            authId, widget.existingMeasurement!.id, req)
        : await provider.createBodyMeasurement(authId, req);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      AppSnack.showSuccess(
          context, _isEditMode ? 'Ölçüler güncellendi ✓' : 'Ölçüler kaydedildi ✓');
    } else {
      setState(() => _isSaving = false);
      AppSnack.showError(context, provider.errorMessage ?? 'Hata oluştu');
    }
  }
}

// ── Date Picker Row ──────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerRow({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) =>
              Theme(data: AppTheme.darkTheme, child: child!),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Text(
              DateFormat('d MMMM yyyy', 'tr_TR').format(date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded,
                color: Colors.white.withValues(alpha: 0.35), size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final labels = ['Üst Gövde', 'Alt Gövde'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isDone   = i < currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : isDone
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : isDone
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDone)
                    const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 13)
                  else
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isActive ? AppColors.primary : Colors.white30,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primaryLight
                          : isDone
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : Colors.white30,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (i < totalSteps - 1)
              Container(
                width: 24,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.12),
              ),
          ],
        );
      }),
    );
  }
}

// ── Form Sections ─────────────────────────────────────────────────────────────

class _UpperBodySection extends StatelessWidget {
  final TextEditingController chestCtrl;
  final TextEditingController waistCtrl;
  final TextEditingController hipsCtrl;
  final TextEditingController leftArmCtrl;
  final TextEditingController rightArmCtrl;

  const _UpperBodySection({
    required this.chestCtrl,
    required this.waistCtrl,
    required this.hipsCtrl,
    required this.leftArmCtrl,
    required this.rightArmCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionLabel(
          icon: Icons.accessibility_new_rounded,
          label: 'Gövde',
          color: const Color(0xFF64D2FF),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Göğüs',  Icons.accessibility_new_rounded, const Color(0xFF64D2FF), chestCtrl),
          right: _FieldDef('Bel',    Icons.straighten_rounded,        const Color(0xFFFF6B6B), waistCtrl),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Kalça',  Icons.self_improvement_rounded,  const Color(0xFFFF9F43), hipsCtrl),
          right: null,
        ),
        const SizedBox(height: 16),
        _SectionLabel(
          icon: Icons.fitness_center_rounded,
          label: 'Kollar',
          color: const Color(0xFF48BB78),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Sol Kol',  Icons.fitness_center_rounded, const Color(0xFF48BB78), leftArmCtrl),
          right: _FieldDef('Sağ Kol', Icons.fitness_center_rounded, const Color(0xFF48BB78), rightArmCtrl),
        ),
      ],
    );
  }
}

class _LowerBodySection extends StatelessWidget {
  final TextEditingController leftLegCtrl;
  final TextEditingController rightLegCtrl;

  const _LowerBodySection({
    required this.leftLegCtrl,
    required this.rightLegCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionLabel(
          icon: Icons.directions_walk_rounded,
          label: 'Bacaklar',
          color: const Color(0xFFA78BFA),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Sol Bacak',  Icons.directions_walk_rounded, const Color(0xFFA78BFA), leftLegCtrl),
          right: _FieldDef('Sağ Bacak', Icons.directions_walk_rounded, const Color(0xFFA78BFA), rightLegCtrl),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.white38, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bacak çevresini en geniş yerinden (uyluğun ortası) ölç.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllFieldsSection extends StatelessWidget {
  final TextEditingController chestCtrl;
  final TextEditingController waistCtrl;
  final TextEditingController hipsCtrl;
  final TextEditingController leftArmCtrl;
  final TextEditingController rightArmCtrl;
  final TextEditingController leftLegCtrl;
  final TextEditingController rightLegCtrl;

  const _AllFieldsSection({
    required this.chestCtrl,
    required this.waistCtrl,
    required this.hipsCtrl,
    required this.leftArmCtrl,
    required this.rightArmCtrl,
    required this.leftLegCtrl,
    required this.rightLegCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FieldRow(
          left:  _FieldDef('Göğüs',     Icons.accessibility_new_rounded,  const Color(0xFF64D2FF), chestCtrl),
          right: _FieldDef('Bel',       Icons.straighten_rounded,          const Color(0xFFFF6B6B), waistCtrl),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Kalça',     Icons.self_improvement_rounded,    const Color(0xFFFF9F43), hipsCtrl),
          right: _FieldDef('Sol Kol',   Icons.fitness_center_rounded,      const Color(0xFF48BB78), leftArmCtrl),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Sağ Kol',  Icons.fitness_center_rounded,      const Color(0xFF48BB78), rightArmCtrl),
          right: _FieldDef('Sol Bacak', Icons.directions_walk_rounded,     const Color(0xFFA78BFA), leftLegCtrl),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          left:  _FieldDef('Sağ Bacak', Icons.directions_walk_rounded,    const Color(0xFFA78BFA), rightLegCtrl),
          right: null,
        ),
      ],
    );
  }
}

// ── Field Row & Input ─────────────────────────────────────────────────────────

class _FieldDef {
  final String label;
  final IconData icon;
  final Color color;
  final TextEditingController ctrl;
  const _FieldDef(this.label, this.icon, this.color, this.ctrl);
}

class _FieldRow extends StatelessWidget {
  final _FieldDef left;
  final _FieldDef? right;
  const _FieldRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _FieldInput(def: left)),
        if (right != null) ...[
          const SizedBox(width: 10),
          Expanded(child: _FieldInput(def: right!)),
        ] else ...[
          const SizedBox(width: 10),
          const Expanded(child: SizedBox.shrink()),
        ],
      ],
    );
  }
}

class _FieldInput extends StatelessWidget {
  final _FieldDef def;
  const _FieldInput({required this.def});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: def.ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: Icon(def.icon, color: def.color.withValues(alpha: 0.7), size: 16),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        labelText: '${def.label} (cm)',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 13,
        ),
        suffixText: 'cm',
        suffixStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: def.color.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: def.color, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: color.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

// ── Buttons ────────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Devam Et',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool isSaving;
  final VoidCallback onTap;
  const _SaveButton({
    required this.label,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton.primary(
        text: isSaving ? 'Kaydediliyor…' : label,
        onPressed: isSaving ? null : onTap,
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
