
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';

class LabelOcrScanPage extends StatefulWidget {
  final MealType initialMealType;

  const LabelOcrScanPage({super.key, required this.initialMealType});

  @override
  State<LabelOcrScanPage> createState() => _LabelOcrScanPageState();
}

class _LabelOcrScanPageState extends State<LabelOcrScanPage> {
  CameraController? _controller;
  final _textRecognizer = TextRecognizer();
  bool _isBusy = false;
  bool _isPermissionGranted = false;
  
  // Parsed values
  double? _kcal;
  double? _protein;
  double? _carb;
  double? _fat;
  
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high, // OCR often needs better resolution
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      _parseNutritionText(recognizedText.text);
      if (mounted) {
          _showEditDialog();
      }

    } catch (e) {
      debugPrint('OCR Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _parseNutritionText(String text) {
    // Basic Regex Parsing Logic
    // Looks for patterns like "Energy ... 100 kcal", "Protein ... 5g", etc.
    final lower = text.toLowerCase().replaceAll(',', '.');
    
    // Helper to find value after a keyword
    double? findValue(List<String> keywords) {
      for (final line in lower.split('\n')) {
        for (final keyword in keywords) {
          if (line.contains(keyword)) {
            // Try to extract numbers in the line
            final regex = RegExp(r'(\d+(\.\d+)?)');
            // final matches = regex.allMatches(line); // Unused
            
            // Usually the value is after the keyword, but sometimes before (e.g. 10g Protein)
            // Let's assume standard table format: Keyword ... Value
            // We take the number closest to the keyword or the first number in line if generic
            
            // Simple approach: find first number *after* the keyword index
            final kwIndex = line.indexOf(keyword);
            final afterKw = line.substring(kwIndex + keyword.length);
            final match = regex.firstMatch(afterKw);
            if (match != null) {
              return double.tryParse(match.group(0)!);
            }
          }
        }
      }
      return null;
    }

    _kcal = findValue(['enerji', 'energy', 'kalori', 'kcal', 'cal']);
    _protein = findValue(['protein']);
    _carb = findValue(['karbonhidrat', 'carb', 'carbohydrate', 'karbo']);
    _fat = findValue(['yağ', 'fat', 'lipid']);
  }

  void _showEditDialog() {
      // Pause preview while editing
      _controller?.pausePreview();

      final kcalCtrl = TextEditingController(text: _kcal?.toString() ?? '');
      final pCtrl = TextEditingController(text: _protein?.toString() ?? '');
      final cCtrl = TextEditingController(text: _carb?.toString() ?? '');
      final fCtrl = TextEditingController(text: _fat?.toString() ?? '');
      
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
              title: const Text('Besin Değerleri (100g)'),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Ürün Adı (İsteğe Bağlı)'),
                          ),
                          TextField(
                              controller: kcalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Kalori (kcal)'),
                          ),
                          TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
                          TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Karbonhidrat (g)')),
                          TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yağ (g)')),
                      ],
                  ),
              ),
              actions: [
                  TextButton(
                      onPressed: () {
                          Navigator.pop(ctx);
                          _controller?.resumePreview();
                      },
                      child: const Text('Tekrar Tara'),
                  ),
                  FilledButton(
                      onPressed: () {
                          // Save
                          final k = double.tryParse(kcalCtrl.text) ?? 0;
                          final p = double.tryParse(pCtrl.text) ?? 0;
                          final c = double.tryParse(cCtrl.text) ?? 0;
                          final f = double.tryParse(fCtrl.text) ?? 0;
                          final name = _nameController.text.isEmpty ? 'Taranmış Ürün' : _nameController.text;
                          
                          Navigator.pop(ctx); // Close dialog
                          _saveAndReturn(name, k, p, c, f);
                      },
                      child: const Text('Kaydet'),
                  ),
              ],
          ),
      );
  }

  Future<void> _saveAndReturn(String name, double k, double p, double c, double f) async {
      try {
          final food = FoodItem(
            id: 'ocr_${DateTime.now().millisecondsSinceEpoch}',
            name: _nameController.text.isEmpty ? 'Taranan Ürün' : _nameController.text,
            category: 'Diğer',
            basis: const FoodBasis(amount: 100, unit: 'g'), // OCR genellikle 100g değerleri okur varsayıyoruz
            nutrients: Nutrients(
              kcal: k,
              protein: p,
              carb: c,
              fat: f,
            ),
          );
          
          final provider = context.read<DietProvider>();
          await provider.addCustomFood(food);
          
          if (mounted) {
              Navigator.pop(context, food);
          }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) return const Scaffold(body: Center(child: Text('Kamera izni yok')));
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: _captureAndProcess,
                child: _isBusy 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
