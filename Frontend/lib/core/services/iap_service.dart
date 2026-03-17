import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// ─── Ürün ID'leri ─────────────────────────────────────────────────────────────
// App Store Connect ve Google Play Console'daki ürün ID'leriyle eşleşmeli.

class IapProductIds {
  static const String monthly = 'premium_monthly';
  static const String yearly = 'premium_yearly';
  static const Set<String> all = {monthly, yearly};
}

// ─── Sonuç modeli ─────────────────────────────────────────────────────────────

class IapPurchaseResult {
  final bool success;
  final String? planId;

  /// Android: Google Play purchase token (backend doğrulaması için)
  final String? purchaseToken;

  /// iOS: App Store server verification data (base64 receipt)
  final String? receiptData;

  /// Benzersiz işlem ID
  final String? transactionId;

  final String? errorMessage;

  const IapPurchaseResult._({
    required this.success,
    this.planId,
    this.purchaseToken,
    this.receiptData,
    this.transactionId,
    this.errorMessage,
  });

  factory IapPurchaseResult.success({
    required String planId,
    String? purchaseToken,
    String? receiptData,
    String? transactionId,
  }) =>
      IapPurchaseResult._(
        success: true,
        planId: planId,
        purchaseToken: purchaseToken,
        receiptData: receiptData,
        transactionId: transactionId,
      );

  factory IapPurchaseResult.failure(String message) =>
      IapPurchaseResult._(success: false, errorMessage: message);

  factory IapPurchaseResult.canceled() =>
      const IapPurchaseResult._(success: false, errorMessage: 'canceled');
}

// ─── Servis ───────────────────────────────────────────────────────────────────

/// App Store / Google Play abonelik satın alma servisi.
///
/// Kullanım:
///   1. `main()` içinde `await IapService.instance.init()` çağır.
///   2. Satın alma başlatmadan önce `onPurchaseComplete` callback'ini set et.
///   3. `purchase(planId)` ile native ödeme sayfasını aç.
///   4. Callback içinde backend'e token gönder → premium aktifleştir.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  bool _available = false;
  bool _initialized = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Satın alma tamamlandığında (başarı / hata / iptal) çağrılır.
  /// PremiumScreen tarafından set edilir; dispose edilince null'lanmalı.
  void Function(IapPurchaseResult)? onPurchaseComplete;

  bool get isAvailable => _available;
  List<ProductDetails> get products => List.unmodifiable(_products);

  // ─── Init / Dispose ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('IapService: mağaza kullanılamıyor (simulator / sandbox?)');
      return;
    }

    // Satın alma stream'ini dinle
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (dynamic error) {
        debugPrint('IapService: stream hatası — $error');
        onPurchaseComplete?.call(
          IapPurchaseResult.failure('Mağaza bağlantı hatası: $error'),
        );
      },
    );

    await _loadProducts();
    debugPrint(
      'IapService: hazır — ${_products.length} ürün yüklendi: '
      '${_products.map((p) => p.id).toList()}',
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ─── Ürünler ────────────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(IapProductIds.all);

      if (response.error != null) {
        debugPrint('IapService: ürün sorgu hatası — ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        // Henüz App Store Connect / Play Console'da eklenmemişse beklenir.
        debugPrint(
          'IapService: bulunamayan ürün ID\'leri — ${response.notFoundIDs}',
        );
      }
      _products = response.productDetails;
    } catch (e) {
      debugPrint('IapService: _loadProducts istisna — $e');
    }
  }

  /// Ürünün mağaza fiyatını döner (ör. "₺149,99").
  /// Ürünler yüklenmemişse null döner; UI fallback fiyatı gösterir.
  String? priceFor(String planId) {
    try {
      return _products.firstWhere((p) => p.id == planId).price;
    } catch (_) {
      return null;
    }
  }

  // ─── Satın Alma ─────────────────────────────────────────────────────────────

  /// [planId]: `IapProductIds.monthly` veya `IapProductIds.yearly`
  ///
  /// Dönen `true`, native ödeme sayfasının açıldığı anlamına gelir.
  /// Gerçek sonuç `onPurchaseComplete` callback'i üzerinden iletilir.
  Future<bool> purchase(String planId) async {
    if (!_available) {
      onPurchaseComplete?.call(
        IapPurchaseResult.failure('Uygulama mağazasına bağlanılamıyor.'),
      );
      return false;
    }

    // Ürün listesi boşsa yeniden yükle
    if (_products.isEmpty) await _loadProducts();

    final matches = _products.where((p) => p.id == planId).toList();
    if (matches.isEmpty) {
      debugPrint(
        'IapService: "$planId" ürünü bulunamadı. '
        'App Store Connect / Play Console\'da ürün eklenmiş mi?',
      );
      onPurchaseComplete?.call(
        IapPurchaseResult.failure(
          'Ürün bilgisi alınamadı. İnternet bağlantını kontrol et.',
        ),
      );
      return false;
    }

    final product = matches.first;
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      // Abonelikler non-consumable olarak satın alınır
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('IapService: purchase() hatası — $e');
      onPurchaseComplete?.call(
        IapPurchaseResult.failure('Satın alma başlatılamadı.'),
      );
      return false;
    }
  }

  /// Geçmiş App Store / Play Store satın almalarını geri yükler.
  Future<void> restorePurchases() async {
    if (!_available) {
      onPurchaseComplete?.call(
        IapPurchaseResult.failure('Uygulama mağazasına bağlanılamıyor.'),
      );
      return;
    }
    try {
      await _iap.restorePurchases();
      // Restore sonuçları da _handlePurchaseUpdates üzerinden gelir.
    } catch (e) {
      debugPrint('IapService: restorePurchases() hatası — $e');
      onPurchaseComplete?.call(
        IapPurchaseResult.failure('Satın alma geçmişi yüklenemedi.'),
      );
    }
  }

  // ─── Stream İşleyici ────────────────────────────────────────────────────────

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint(
        'IapService: güncelleme — '
        'id=${purchase.productID} status=${purchase.status}',
      );
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _onSuccess(purchase);
        case PurchaseStatus.error:
          final msg =
              purchase.error?.message ?? 'Satın alma sırasında hata oluştu.';
          debugPrint('IapService: hata — $msg');
          onPurchaseComplete?.call(IapPurchaseResult.failure(msg));
          _safeComplete(purchase);
        case PurchaseStatus.canceled:
          debugPrint('IapService: kullanıcı iptal etti.');
          onPurchaseComplete?.call(IapPurchaseResult.canceled());
          _safeComplete(purchase);
        case PurchaseStatus.pending:
          // Banka onayı beklenebilir (örn. aile paylaşımı onayı)
          debugPrint('IapService: ödeme bekleniyor — ${purchase.productID}');
      }
    }
  }

  void _onSuccess(PurchaseDetails purchase) {
    // Platform bazlı doğrulama verisini ayır.
    // verificationData.source → 'google_play' | 'app_store'
    final data = purchase.verificationData;
    final isAndroid = data.source == 'google_play';

    onPurchaseComplete?.call(
      IapPurchaseResult.success(
        planId: purchase.productID,
        purchaseToken: isAndroid ? data.serverVerificationData : null,
        receiptData: isAndroid ? null : data.serverVerificationData,
        transactionId: purchase.purchaseID,
      ),
    );

    // Google Play: acknowledge / iOS: finish transaction
    // Yapılmazsa satın alma tekrar tetiklenebilir.
    _safeComplete(purchase);
  }

  void _safeComplete(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }
}
