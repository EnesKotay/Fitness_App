import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'barcode_link_food_page.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../data/repositories/barcode_food_repository.dart';

class BarcodeScanPage extends StatefulWidget {
  final MealType initialMealType;

  const BarcodeScanPage({super.key, required this.initialMealType});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isBusy = false;
  bool _isPermissionGranted = false;
  bool _isPermissionPermanentlyDenied = false;
  DateTime? _lastScanTime;
  final _repo = BarcodeFoodRepository();
  late final Future<void> _repoInitFuture;

  @override
  void initState() {
    super.initState();
    _repoInitFuture = _repo.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermission();
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _isPermissionGranted = status.isGranted;
      _isPermissionPermanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isBusy) return;

    if (_lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    _isBusy = true;
    _lastScanTime = DateTime.now();

    try {
      await _handleBarcodeDetected(rawValue);
    } catch (e) {
      debugPrint('Error processing barcode: $e');
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _handleBarcodeDetected(String barcode) async {
    await _controller.stop();

    if (!mounted) return;

    await _repoInitFuture;
    if (!mounted) return;

    final dietProvider = context.read<DietProvider>();

    // 1. Önce kullanıcının manuel bağladığı barcode -> food eşleşmesini ara
    final foodId = _repo.getFoodId(barcode);
    if (foodId != null) {
      final food = await dietProvider.getFoodById(foodId);

      if (food != null && mounted) {
        _showFoundDialog(food);
        return;
      }
    }

    // 2. Sonra lokal barkod alanı + remote OFF fallback
    final directFood = await dietProvider.getFoodByBarcode(barcode);
    if (directFood != null && mounted) {
      _showFoundDialog(directFood);
      return;
    }

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeLinkFoodPage(
            barcode: barcode,
            mealType: widget.initialMealType,
          ),
        ),
      );

      if (!mounted) return;
      if (result is FoodItem) {
        Navigator.pop(context, result);
      } else if (result == true) {
        Navigator.pop(context);
      } else {
        await _controller.start();
      }
    }
  }

  void _showFoundDialog(FoodItem food) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün Bulundu!'),
        content: Text(food.name),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.start();
            },
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addFoodToMeal(food);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _addFoodToMeal(FoodItem food) {
    Navigator.pop(context, food);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Barkod Tara')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isPermissionPermanentlyDenied
                    ? 'Kamera izni kalıcı olarak kapalı'
                    : 'Kamera izni gerekli',
              ),
              const SizedBox(height: 8),
              Text(
                _isPermissionPermanentlyDenied
                    ? 'Ayarlar ekranından kamerayı açın.'
                    : 'Barkod taramak için kamera izni verin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isPermissionPermanentlyDenied
                    ? openAppSettings
                    : _requestPermission,
                child: Text(
                  _isPermissionPermanentlyDenied
                      ? 'Ayarları Aç'
                      : 'İzni Tekrar Sor',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onBarcodeDetected),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Barkodu kare içine alın',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay shape (değişmedi)
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutWidth = cutOutSize;
    final cutOutHeight = cutOutSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      width / 2 - cutOutWidth / 2,
      height / 2 - cutOutHeight / 2,
      cutOutWidth,
      cutOutHeight,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRect(cutOutRect, Paint()..blendMode = BlendMode.clear)
      ..restore();

    final r = cutOutRect;

    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.top + borderLength)
        ..lineTo(r.left, r.top + borderRadius)
        ..quadraticBezierTo(r.left, r.top, r.left + borderRadius, r.top)
        ..lineTo(r.left + borderLength, r.top),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r.right, r.top + borderLength)
        ..lineTo(r.right, r.top + borderRadius)
        ..quadraticBezierTo(r.right, r.top, r.right - borderRadius, r.top)
        ..lineTo(r.right - borderLength, r.top),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r.right, r.bottom - borderLength)
        ..lineTo(r.right, r.bottom - borderRadius)
        ..quadraticBezierTo(r.right, r.bottom, r.right - borderRadius, r.bottom)
        ..lineTo(r.right - borderLength, r.bottom),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.bottom - borderLength)
        ..lineTo(r.left, r.bottom - borderRadius)
        ..quadraticBezierTo(r.left, r.bottom, r.left + borderRadius, r.bottom)
        ..lineTo(r.left + borderLength, r.bottom),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
