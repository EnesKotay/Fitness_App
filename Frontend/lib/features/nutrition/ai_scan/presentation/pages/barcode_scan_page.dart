
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'barcode_link_food_page.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../data/datasources/hive_diet_storage.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../../presentation/widgets/visual_meal_card.dart';
import '../../data/repositories/barcode_food_repository.dart';

class BarcodeScanPage extends StatefulWidget {
  final MealType initialMealType;

  const BarcodeScanPage({super.key, required this.initialMealType});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  CameraController? _controller;
  final _barcodeScanner = BarcodeScanner();
  bool _isBusy = false;
  bool _isPermissionGranted = false;
  DateTime? _lastScanTime;
  final _repo = BarcodeFoodRepository();

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _repo.init();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream(_processImage);
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isBusy || !_isPermissionGranted || _controller == null) return;
    
    // Cooldown check (2 seconds)
    if (_lastScanTime != null && DateTime.now().difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        final rawValue = barcode.rawValue;
        
        if (rawValue != null) {
            _lastScanTime = DateTime.now();
            await _handleBarcodeDetected(rawValue);
        }
      }
    } catch (e) {
      debugPrint('Error processing barcode: $e');
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _handleBarcodeDetected(String barcode) async {
      // Pause camera during processing
      await _controller?.pausePreview();

      if (!mounted) return;

      // 1. Check local mapping first
      final foodId = _repo.getFoodId(barcode);
      
      if (foodId != null) {
          // Found locally mapped food
          final dietProvider = context.read<DietProvider>();
          final food = await dietProvider.getFoodById(foodId);
          
          if (food != null && mounted) {
              _showFoundDialog(food);
              return;
          }
      }

      // 2. If not mapped, check existing DB by barcode (if supported) 
      // or check OpenFoodFacts via DietProvider's remote repo
      
      // For this MVP, we will simulate a "Not Found" scenario which leads to linking
      // Or we can try to search in DietProvider if it supports searching by "barcode:{code}"
      // But typically we just redirect to Link Page if local mapping fails or returns nothing.
      
      if (mounted) {
          final result = await Navigator.push(
              context, 
              MaterialPageRoute(
                  builder: (_) => BarcodeLinkFoodPage(barcode: barcode, mealType: widget.initialMealType)
              )
          );
          
          if (result == true) {
              // Successfully linked and added
              if (mounted) Navigator.pop(context);
          } else {
              // Cancelled, resume scanning
              await _controller?.resumePreview();
          }
      }
  }

  void _showFoundDialog(FoodItem food) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: Text('Ürün Bulundu!'),
              content: Text(food.name),
              actions: [
                  TextButton(
                      onPressed: () {
                          Navigator.pop(ctx); // Close dialog
                          _controller?.resumePreview();
                      }, 
                      child: Text('İptal')
                  ),
                  FilledButton(
                      onPressed: () {
                          Navigator.pop(ctx); // Close dialog
                          // Navigate to add portion page or add directly
                          // For now, let's close scanner and return result
                           _addFoodToMeal(food);
                      }, 
                      child: Text('Ekle')
                  ),
              ],
          )
      );
  }

  void _addFoodToMeal(FoodItem food) {
      // Here we should probably show a bottom sheet or dialog to select grams
      // For MVP, simplified:
      Navigator.pop(context, food); 
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // InputImageRotationValue.fromRawValue is not always reliable across versions/platforms.
    // We map it manually or assume rotation0deg if failing, but checking rotation is safer.
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

    // Determine format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    
    // Validate format and rotation
    if (format == null) return null;

    // Create InputImageMetadata
    // Note: older versions used InputImageData, newer use InputImageMetadata
    // And fromBytes takes 'metadata' named argument.
    
    // For specific Android/iOS bytesPerRow:
    // On Android, planes[0].bytesPerRow is often the stride.
    // On iOS, it's consistent.
    if (image.planes.isEmpty) return null;
    
    final plane = image.planes.first;
    
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: plane.bytes, 
      metadata: metadata,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _barcodeScanner.close();
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
              const Text('Kamera izni gerekli'),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Ayarları Aç'),
              )
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
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
                 style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
             ),
          )
        ],
      ),
    );
  }
}

// Helper for Overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
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
    final borderRadius = this.borderRadius;
    final borderLength = this.borderLength;

    // Top left
    canvas.drawPath(
       Path()
        ..moveTo(r.left, r.top + borderLength)
        ..lineTo(r.left, r.top + borderRadius)
        ..quadraticBezierTo(r.left, r.top, r.left + borderRadius, r.top)
        ..lineTo(r.left + borderLength, r.top),
       borderPaint
    );
     // Top right
    canvas.drawPath(
       Path()
        ..moveTo(r.right, r.top + borderLength)
        ..lineTo(r.right, r.top + borderRadius)
        ..quadraticBezierTo(r.right, r.top, r.right - borderRadius, r.top)
        ..lineTo(r.right - borderLength, r.top),
       borderPaint
    );
    // Bottom right
    canvas.drawPath(
       Path()
        ..moveTo(r.right, r.bottom - borderLength)
        ..lineTo(r.right, r.bottom - borderRadius)
        ..quadraticBezierTo(r.right, r.bottom, r.right - borderRadius, r.bottom)
        ..lineTo(r.right - borderLength, r.bottom),
       borderPaint
    );
    // Bottom left
    canvas.drawPath(
       Path()
        ..moveTo(r.left, r.bottom - borderLength)
        ..lineTo(r.left, r.bottom - borderRadius)
        ..quadraticBezierTo(r.left, r.bottom, r.left + borderRadius, r.bottom)
        ..lineTo(r.left + borderLength, r.bottom),
       borderPaint
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
