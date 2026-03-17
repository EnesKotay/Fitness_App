import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../data/repositories/barcode_food_repository.dart';

class BarcodeLinkFoodPage extends StatefulWidget {
  final String barcode;
  final MealType mealType;

  const BarcodeLinkFoodPage({
    super.key,
    required this.barcode,
    required this.mealType,
  });

  @override
  State<BarcodeLinkFoodPage> createState() => _BarcodeLinkFoodPageState();
}

class _BarcodeLinkFoodPageState extends State<BarcodeLinkFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController(text: '0');
  final _carbController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  Timer? _debounce;
  bool _isLoading = false;
  bool _isSearching = false;
  List<FoodItem> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _searchFoods);
  }

  Future<void> _searchFoods() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final provider = context.read<DietProvider>();
      final results = await provider.searchFoods(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results.take(8).toList();
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _linkExistingFood(FoodItem food) async {
    setState(() => _isLoading = true);
    try {
      final repo = BarcodeFoodRepository();
      await repo.saveMapping(widget.barcode, food.id);
      if (!mounted) return;
      Navigator.pop(context, food);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eşleme kaydedilemedi: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndLinkNewFood() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final kcal = double.parse(_kcalController.text.replaceAll(',', '.'));
      final p =
          double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 0;
      final c = double.tryParse(_carbController.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0;

      final newFood = FoodItem(
        id: const Uuid().v4(),
        name: name,
        category: 'Barkodlu',
        basis: const FoodBasis(amount: 100, unit: 'g'),
        nutrients: Nutrients(kcal: kcal, protein: p, carb: c, fat: f),
      );

      final provider = context.read<DietProvider>();
      await provider.addCustomFood(newFood);

      final repo = BarcodeFoodRepository();
      await repo.saveMapping(widget.barcode, newFood.id);

      if (!mounted) return;
      Navigator.pop(context, newFood);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barkodu Eşleştir')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildExistingFoodSection(),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _buildNewFoodSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.qr_code_rounded, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Barkod: ${widget.barcode}\nÖnce mevcut bir yemeğe bağlayabilir, bulamazsan yeni ürün oluşturabilirsin.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingFoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mevcut yemeğe bağla',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Örn: süt, yoğurt, ton balığı, ekmek',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Yemek ara',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_searchController.text.trim().isNotEmpty &&
            _searchResults.isEmpty &&
            !_isSearching)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text(
              'Eşleşen yemek bulunamadı. Alttan yeni ürün oluşturabilirsin.',
            ),
          ),
        if (_searchResults.isNotEmpty)
          ..._searchResults.map(_buildSearchResultTile),
      ],
    );
  }

  Widget _buildSearchResultTile(FoodItem food) {
    final brandSuffix = food.brand != null && food.brand!.trim().isNotEmpty
        ? ' • ${food.brand}'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${food.category}$brandSuffix\n${food.kcalPer100g.round()} kcal / 100g',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: FilledButton(
          onPressed: _isLoading ? null : () => _linkExistingFood(food),
          child: const Text('Bağla'),
        ),
      ),
    );
  }

  Widget _buildNewFoodSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Yeni ürün oluştur',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bu barkod için veritabanına yeni bir ürün kaydet.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ürün Adı',
              border: OutlineInputBorder(),
              hintText: 'Örn: Tam Buğday Ekmeği',
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Gerekli' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _kcalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'kcal / 100g',
              border: OutlineInputBorder(),
              suffixText: 'kcal',
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Gerekli' : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Makrolar (100g için opsiyonel)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMacroField(
                  _proteinController,
                  'Protein',
                  'g',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroField(
                  _carbController,
                  'Karb',
                  'g',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroField(_fatController, 'Yağ', 'g', Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _saveAndLinkNewFood,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Yeni Ürün Olarak Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroField(
    TextEditingController ctrl,
    String label,
    String suffix,
    Color color,
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
