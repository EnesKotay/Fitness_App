import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/models/body_measurement.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tracking_provider.dart';

class AddMeasurementSheet extends StatefulWidget {
  final BodyMeasurement? existingMeasurement;
  const AddMeasurementSheet({super.key, this.existingMeasurement});

  @override
  State<AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<AddMeasurementSheet> {
  late DateTime _selectedDate;
  late final TextEditingController _dateController;

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
    final existing = widget.existingMeasurement;
    _selectedDate = existing?.date ?? DateTime.now();
    _dateController = TextEditingController(
      text: DateFormat('d.MM.yyyy').format(_selectedDate),
    );
    _chestCtrl = TextEditingController(
      text: existing?.chest?.toStringAsFixed(1) ?? '',
    );
    _waistCtrl = TextEditingController(
      text: existing?.waist?.toStringAsFixed(1) ?? '',
    );
    _hipsCtrl = TextEditingController(
      text: existing?.hips?.toStringAsFixed(1) ?? '',
    );
    _leftArmCtrl = TextEditingController(
      text: existing?.leftArm?.toStringAsFixed(1) ?? '',
    );
    _rightArmCtrl = TextEditingController(
      text: existing?.rightArm?.toStringAsFixed(1) ?? '',
    );
    _leftLegCtrl = TextEditingController(
      text: existing?.leftLeg?.toStringAsFixed(1) ?? '',
    );
    _rightLegCtrl = TextEditingController(
      text: existing?.rightLeg?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipsCtrl.dispose();
    _leftArmCtrl.dispose();
    _rightArmCtrl.dispose();
    _leftLegCtrl.dispose();
    _rightLegCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isEditMode ? 'Ölçüleri Düzenle' : 'Mezura Ölçüleri Ekle',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) =>
                    Theme(data: AppTheme.darkTheme, child: child!),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _dateController.text = DateFormat('d.MM.yyyy').format(picked);
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dateController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildInputRow('Göğüs', _chestCtrl, 'Bel', _waistCtrl),
                  const SizedBox(height: 16),
                  _buildInputRow('Kalça', _hipsCtrl, 'Sol Kol', _leftArmCtrl),
                  const SizedBox(height: 16),
                  _buildInputRow(
                    'Sağ Kol',
                    _rightArmCtrl,
                    'Sol Bacak',
                    _leftLegCtrl,
                  ),
                  const SizedBox(height: 16),
                  _buildInputRow('Sağ Bacak', _rightLegCtrl, null, null),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: _isEditMode ? 'Güncelle' : 'Kaydet',
              onPressed: _saveMeasurement,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    String label1,
    TextEditingController ctrl1,
    String? label2,
    TextEditingController? ctrl2,
  ) {
    return Row(
      children: [
        Expanded(child: _buildInputField(label1, ctrl1)),
        if (label2 != null && ctrl2 != null) ...[
          const SizedBox(width: 16),
          Expanded(child: _buildInputField(label2, ctrl2)),
        ] else ...[
          const SizedBox(width: 16),
          const Expanded(child: SizedBox.shrink()),
        ],
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: '$label (cm)',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  void _saveMeasurement() async {
    final chest = double.tryParse(_chestCtrl.text.replaceAll(',', '.'));
    final waist = double.tryParse(_waistCtrl.text.replaceAll(',', '.'));
    final hips = double.tryParse(_hipsCtrl.text.replaceAll(',', '.'));
    final leftArm = double.tryParse(_leftArmCtrl.text.replaceAll(',', '.'));
    final rightArm = double.tryParse(_rightArmCtrl.text.replaceAll(',', '.'));
    final leftLeg = double.tryParse(_leftLegCtrl.text.replaceAll(',', '.'));
    final rightLeg = double.tryParse(_rightLegCtrl.text.replaceAll(',', '.'));

    if (chest == null &&
        waist == null &&
        hips == null &&
        leftArm == null &&
        rightArm == null &&
        leftLeg == null &&
        rightLeg == null) {
      AppSnack.showError(context, 'En az bir ölçü girmelisiniz.');
      return;
    }

    final labeled = <String, double?>{
      'Göğüs': chest, 'Bel': waist, 'Kalça': hips,
      'Sol Kol': leftArm, 'Sağ Kol': rightArm,
      'Sol Bacak': leftLeg, 'Sağ Bacak': rightLeg,
    };
    for (final entry in labeled.entries) {
      final v = entry.value;
      if (v != null && (v <= 0 || v > 300)) {
        AppSnack.showError(context, '${entry.key} için geçerli bir değer girin (1–300 cm).');
        return;
      }
    }

    final req = BodyMeasurementRequest(
      date: _selectedDate,
      chest: chest,
      waist: waist,
      hips: hips,
      leftArm: leftArm,
      rightArm: rightArm,
      leftLeg: leftLeg,
      rightLeg: rightLeg,
    );

    final provider = context.read<TrackingProvider>();
    final authId = context.read<AuthProvider>().user?.id;
    if (authId == null || authId <= 0) {
      AppSnack.showError(
        context,
        'Kullanıcı oturumu bulunamadı. Lütfen yeniden giriş yapın.',
      );
      return;
    }

    bool success;
    if (_isEditMode) {
      success = await provider.updateBodyMeasurement(
        authId,
        widget.existingMeasurement!.id,
        req,
      );
    } else {
      success = await provider.createBodyMeasurement(authId, req);
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnack.showSuccess(
        context,
        _isEditMode ? 'Ölçüler güncellendi' : 'Ölçüler kaydedildi',
      );
    } else {
      AppSnack.showError(context, provider.errorMessage ?? 'Hata oluştu');
    }
  }
}
