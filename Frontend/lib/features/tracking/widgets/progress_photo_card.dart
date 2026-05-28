import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snack.dart';

/// Progress photo card – locally stored (SharedPreferences + file path)
class ProgressPhotoCard extends StatefulWidget {
  const ProgressPhotoCard({super.key});

  @override
  State<ProgressPhotoCard> createState() => _ProgressPhotoCardState();
}

class _ProgressPhotoCardState extends State<ProgressPhotoCard> {
  static const _prefsKey = 'progress_photos_v1';

  List<_PhotoEntry> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final List<dynamic> list = jsonDecode(raw);
      _photos = list.map((e) => _PhotoEntry.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_photos.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final source = await _showSourceDialog();
    if (source == null) return;

    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;

    final entry = _PhotoEntry(path: file.path, date: DateTime.now());
    setState(() => _photos.insert(0, entry));
    await _save();
    if (mounted) AppSnack.showSuccess(context, 'Fotoğraf kaydedildi ✓');
  }

  Future<void> _delete(_PhotoEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Fotoğrafı Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Bu fotoğrafı silmek istediğine emin misin?',
            style: TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _photos.remove(entry));
      await _save();
    }
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border:
              Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Fotoğraf Kaynağı',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _sourceOption(Icons.camera_alt_rounded, 'Kamera',
                () => Navigator.pop(context, ImageSource.camera)),
            const SizedBox(height: 10),
            _sourceOption(Icons.photo_library_rounded, 'Galeri',
                () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      color: Color(0xFFA78BFA), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Görsel İlerleme',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text('Fotoğraf bazlı değişim takibi',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                if (_photos.length >= 2)
                  GestureDetector(
                    onTap: () => _showCompareSlider(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.compare_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Kıyasla', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFA78BFA)
                              .withValues(alpha: 0.35)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.add_rounded,
                          color: Color(0xFFA78BFA), size: 16),
                      SizedBox(width: 4),
                      Text('Ekle',
                          style: TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),

          // ── Content ───────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_photos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  Icon(Icons.camera_alt_rounded,
                      color: Colors.white.withValues(alpha: 0.18), size: 40),
                  const SizedBox(height: 12),
                  Text('İlk ilerleme fotoğrafını ekle',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Görsel değişimi takip etmek için ayda bir çek',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11)),
                ],
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final p = _photos[i];
                  final file = File(p.path);
                  final exists = file.existsSync();
                  return GestureDetector(
                    onTap: exists ? () => _showFullScreen(context, p) : null,
                    child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: exists
                            ? Image.file(file,
                                width: 90,
                                height: 116,
                                fit: BoxFit.cover)
                            : Container(
                                width: 90,
                                height: 116,
                                color: Colors.white.withValues(alpha: 0.05),
                                child: const Icon(Icons.broken_image,
                                    color: Colors.white24)),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14)),
                          ),
                          child: Text(
                            DateFormat('d MMM', 'tr_TR').format(p.date),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA78BFA)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Yeni',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      // Silme butonu
                      Positioned(
                        top: 5,
                        left: 5,
                        child: GestureDetector(
                          onTap: () => _delete(p),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ],
                  ));
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, _PhotoEntry entry) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullScreenPhotoViewer(entry: entry),
    );
  }

  void _showCompareSlider(BuildContext context) {
    if (_photos.length < 2) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: _BeforeAfterSlider(
          beforePath: _photos.last.path,
          afterPath: _photos.first.path,
          beforeDate: _photos.last.date,
          afterDate: _photos.first.date,
        ),
      ),
    );
  }
}

class _PhotoEntry {
  final String path;
  final DateTime date;

  _PhotoEntry({required this.path, required this.date});

  Map<String, dynamic> toJson() => {
        'path': path,
        'date': date.toIso8601String(),
      };

  factory _PhotoEntry.fromJson(Map<String, dynamic> j) => _PhotoEntry(
        path: j['path'] as String,
        date: DateTime.parse(j['date'] as String),
      );
}

class _BeforeAfterSlider extends StatefulWidget {
  final String beforePath;
  final String afterPath;
  final DateTime beforeDate;
  final DateTime afterDate;

  const _BeforeAfterSlider({
    required this.beforePath,
    required this.afterPath,
    required this.beforeDate,
    required this.afterDate,
  });

  @override
  State<_BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<_BeforeAfterSlider> {
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(File(widget.beforePath), fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: ClipRect(
                clipper: _SliderClipper(_sliderPosition),
                child: Image.file(File(widget.afterPath), fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sliderPosition = (_sliderPosition + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned(
                          left: constraints.maxWidth * _sliderPosition - 1.5,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 3, color: Colors.white),
                        ),
                        Positioned(
                          left: constraints.maxWidth * _sliderPosition - 20,
                          top: constraints.maxHeight / 2 - 20,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.compare_arrows, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _buildLabel('Önceki', widget.beforeDate),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _buildLabel('Sonraki', widget.afterDate),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(DateFormat('d MMM yyyy', 'tr_TR').format(date), style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Tam Ekran Fotoğraf Görüntüleyici ─────────────────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  final _PhotoEntry entry;
  const _FullScreenPhotoViewer({required this.entry});

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer>
    with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _resetAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_resetAnim != null) {
          _transformCtrl.value = _resetAnim!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _resetAnim = Matrix4Tween(
      begin: _transformCtrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.entry.path);
    final dateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(widget.entry.date);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Arka plan — tıklayınca kapat
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),

          // Fotoğraf — pinch zoom destekli
          Center(
            child: GestureDetector(
              onDoubleTap: _resetZoom,
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 1.0,
                maxScale: 5.0,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),

          // Tarih etiketi
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Kapat butonu
          Positioned(
            top: 48,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double position;
  _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(size.width * position, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.position != position;
}
