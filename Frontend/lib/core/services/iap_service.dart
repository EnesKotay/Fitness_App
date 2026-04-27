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
  final void Function()? complete;

  const IapPurchaseResult._({
    required this.success,
    this.planId,
    this.purchaseToken,
    this.receiptData,
    this.transactionId,
    this.errorMessage,
    this.complete,
  });

  factory IapPurchaseResult.success({
    required String planId,
    String? purchaseToken,
    String? receiptData,
    String? transactionId,
    void Function()? complete,
  }) => IapPurchaseResult._(
    success: true,
    planId: planId,
    purchaseToken: purchaseToken,
    receiptData: receiptData,
    transactionId: transactionId,
    complete: complete,
  );

  factory IapPurchaseResult.failure(String message) =>
      IapPurchaseResult._(success: false, errorMessage: message);

  factory IapPurchaseResult.canceled() =>
      const IapPurchaseResult._(success: false, errorMessage: 'canceled');

  factory IapPurchaseResult.pending() =>
      const IapPurchaseResult._(success: false, errorMessage: 'pending');
}

// ─── Servis ───────────────────────────────────────────────────────────────────

/// App Store / Google Play abonelik satın alma servisi.
///
/// Kullanım:
///   1. `main()` içinde `await IapService.instance.init()` çağır.
///   2. Satın alma başlatmadan önce `onPurchaseComplete` callback'ini set et.
///   3. `purchase(planId)` ile native ödeme sayfasını aç.
///   4. Callback içinde backend'e token gönder → premium aktifleştir.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  bool _available = false;
  bool _initialized = false;
  bool _isLoadingProducts = false;
  List<ProductDetails> _products = [];
  String? _productLoadError;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initFuture;
  final Set<String> _processingPurchaseKeys = <String>{};
  final Set<String> _completedPurchaseKeys = <String>{};

  final _purchaseResultController = StreamController<IapPurchaseResult>.broadcast();
  Stream<IapPurchaseResult> get purchaseResultStream => _purchaseResultController.stream;

  bool get isAvailable => _available;
  bool get isLoadingProducts => _isLoadingProducts;
  String? get productLoadError => _productLoadError;
  List<ProductDetails> get products => List.unmodifiable(_products);

  // ─── Init / Dispose ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _initFuture ??= _initialize();
    await _initFuture;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Satın alma stream'ini dinle
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (dynamic error) {
        debugPrint('IapService: stream hatası — $error');
        _purchaseResultController.add(
          IapPurchaseResult.failure(
            'App Store bağlantısında bir sorun oluştu. '
            'İnternet bağlantını kontrol edip birkaç dakika sonra tekrar dene.',
          ),
        );
      },
    );

    await refreshProducts();
    debugPrint(
      'IapService: hazır — ${_products.length} ürün yüklendi: '
      '${_products.map((p) => p.id).toList()}',
    );
  }

  /// Uygulama arka plana alındığında / detached olduğunda stream'i iptal eder.
  /// Singleton olduğu için [dispose] yerine bunu kullan; ChangeNotifier'ı kapatmaz.
  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
    _initFuture = null;
    _initialized = false;
  }

  @override
  void dispose() {
    cancelSubscription();
    super.dispose();
  }

  // ─── Ürünler ────────────────────────────────────────────────────────────────

  Future<void> refreshProducts() async {
    _isLoadingProducts = true;
    _productLoadError = null;
    notifyListeners();

    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        _products = [];
        _productLoadError =
            'App Store\'a şu an bağlanılamıyor. '
            'Uçak modu kapalı ve internet bağlantın var mı?';
        debugPrint('IapService: mağaza kullanılamıyor (simulator / sandbox?)');
        return;
      }

      final response = await _iap.queryProductDetails(IapProductIds.all);

      if (response.error != null) {
        debugPrint('IapService: ürün sorgu hatası — ${response.error}');
        _productLoadError =
            'Abonelik fiyatları alınamadı. Lütfen sayfayı kapatıp tekrar aç.';
      }
      if (response.notFoundIDs.isNotEmpty) {
        // Henüz App Store Connect / Play Console'da eklenmemişse beklenir.
        debugPrint(
          'IapService: bulunamayan ürün ID\'leri — ${response.notFoundIDs}',
        );
        // Yalnızca hiç ürün gelmediyse hata göster; bazıları bulunduysa devam et.
        if (response.productDetails.isEmpty) {
          _productLoadError =
              'Abonelik paketleri henüz mağazada aktif değil. '
              'Yayına alındıktan birkaç saat sonra tekrar dene.';
        }
      }

      _products = [...response.productDetails]
        ..sort((a, b) {
          final aIndex = _sortIndexFor(a.id);
          final bIndex = _sortIndexFor(b.id);
          return aIndex.compareTo(bIndex);
        });

      if (_products.isEmpty && _productLoadError == null) {
        _productLoadError =
            'Abonelik seçenekleri yüklenemedi. '
            'İnternet bağlantını kontrol edip sayfayı yenile.';
      }
    } catch (e) {
      debugPrint('IapService: _loadProducts istisna — $e');
      _products = [];
      _productLoadError =
          'Abonelik bilgileri alınamadı. '
          'İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
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
      await refreshProducts();
    }

    if (!_available) {
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'App Store\'a bağlanılamıyor. '
          'İnternet bağlantını kontrol edip tekrar dene.',
        ),
      );
      return false;
    }

    // Ürün listesi boşsa yeniden yükle
    if (_products.isEmpty) await refreshProducts();

    final matches = _products.where((p) => p.id == planId).toList();
    if (matches.isEmpty) {
      debugPrint(
        'IapService: "$planId" ürünü bulunamadı. '
        'App Store Connect / Play Console\'da ürün eklenmiş mi?',
      );
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Bu abonelik paketi şu an hazır değil. '
          'Birkaç dakika bekleyip tekrar dene.',
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
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alma başlatılamadı. '
          'Lütfen tekrar dene veya uygulamayı yeniden başlat.',
        ),
      );
      return false;
    }
  }

  /// Geçmiş App Store / Play Store satın almalarını geri yükler.
  Future<void> restorePurchases() async {
    if (!_available) {
      await refreshProducts();
    }

    if (!_available) {
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alımları geri yüklemek için '
          'internet bağlantın gerekli. Lütfen bağlantını kontrol et.',
        ),
      );
      return;
    }
    try {
      await _iap.restorePurchases();
      // Restore sonuçları da _handlePurchaseUpdates üzerinden gelir.
    } catch (e) {
      debugPrint('IapService: restorePurchases() hatası — $e');
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alım geçmişin yüklenemedi. '
          'Lütfen tekrar dene.',
        ),
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
          unawaited(_onSuccess(purchase));
        case PurchaseStatus.error:
          final rawMsg = purchase.error?.message ?? '';
          debugPrint('IapService: hata — $rawMsg (code=${purchase.error?.code})');
          _purchaseResultController.add(
            IapPurchaseResult.failure(_localizeStoreError(purchase.error)),
          );
          _safeComplete(purchase);
        case PurchaseStatus.canceled:
          debugPrint('IapService: kullanıcı iptal etti.');
          _purchaseResultController.add(IapPurchaseResult.canceled());
          _safeComplete(purchase);
        case PurchaseStatus.pending:
          // Banka onayı beklenebilir (örn. aile paylaşımı / ebeveyn onayı)
          debugPrint('IapService: ödeme bekleniyor — ${purchase.productID}');
          _purchaseResultController.add(IapPurchaseResult.pending());
      }
    }
  }

  Future<void> _onSuccess(PurchaseDetails purchase) async {
    final purchaseKey = _purchaseKeyFor(purchase);
    if (_completedPurchaseKeys.contains(purchaseKey)) {
      debugPrint(
        'IapService: duplicate purchase ignored (completed) — $purchaseKey',
      );
      return;
    }
    if (_processingPurchaseKeys.contains(purchaseKey)) {
      debugPrint(
        'IapService: duplicate purchase ignored (processing) — $purchaseKey',
      );
      return;
    }
    _processingPurchaseKeys.add(purchaseKey);

    // Platform bazlı doğrulama verisini ayır.
    // verificationData.source → 'google_play' | 'app_store'
    final data = purchase.verificationData;
    final isAndroid = data.source == 'google_play';
    final result = IapPurchaseResult.success(
      planId: purchase.productID,
      purchaseToken: isAndroid ? data.serverVerificationData : null,
      receiptData: isAndroid ? null : data.serverVerificationData,
      transactionId: purchase.purchaseID,
      complete: () {
        _completedPurchaseKeys.add(purchaseKey);
        _safeComplete(purchase);
        _processingPurchaseKeys.remove(purchaseKey);
      },
    );

    _purchaseResultController.add(result);
    // Note: The caller (PremiumScreen) is now responsible for calling result.complete()
    // if backend verification succeeds. If it fails, they shouldn't call it.
  }

  String _purchaseKeyFor(PurchaseDetails purchase) {
    final transactionId = purchase.purchaseID?.trim();
    if (transactionId != null && transactionId.isNotEmpty) {
      return transactionId;
    }
    final verification = purchase.verificationData.serverVerificationData
        .trim();
    if (verification.isNotEmpty) {
      return '${purchase.productID}::$verification';
    }
    return '${purchase.productID}::${purchase.transactionDate ?? 'unknown'}';
  }

  void _safeComplete(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }

  /// Apple / Google'dan gelen ham store hatasını kullanıcı dostu Türkçeye çevirir.
  /// iOS SKError: https://developer.apple.com/documentation/storekit/skerror
  /// Android BillingClient.BillingResponseCode: sayısal string olarak gelir.
  String _localizeStoreError(IAPError? error) {
    if (error == null) {
      return 'Satın alma sırasında bir hata oluştu. Lütfen tekrar dene.';
    }
    final code = error.code; // String — örn. "SKErrorPaymentCancelled" veya "2"
    switch (code) {
      // iOS — kullanıcı kendi iptal etti
      case 'SKErrorPaymentCancelled':
      case 'userCancelled':
        return 'canceled';
      // iOS — ağ hatası
      case 'SKErrorCloudServiceNetworkConnectionFailed':
        return 'Ağ bağlantısı hatası. İnternetini kontrol edip tekrar dene.';
      // iOS — cihazda satın alma kısıtlı
      case 'SKErrorPaymentNotAllowed':
        return 'Bu cihazda satın alma kısıtlanmış. '
            'Ayarlar → Ekran Süresi → İçerik ve Gizlilik Kısıtlamaları\'nı kontrol et.';
      // iOS — ürün mevcut değil
      case 'SKErrorStoreProductNotAvailable':
        return 'Bu abonelik paketi şu an mağazada mevcut değil. Daha sonra tekrar dene.';
      // iOS — zaten satın alınmış
      case 'SKErrorAlreadyPurchased':
      case 'itemAlreadyOwned':
        return 'Bu aboneliğe zaten sahipsin. '
            'Aşağıdaki "Satın alımları geri yükle" butonunu kullan.';
      // Android — kullanıcı iptal
      case '1':
        return 'canceled';
      // Android — ağ hatası
      case '6':
        return 'Ağ bağlantısı hatası. İnternetini kontrol edip tekrar dene.';
      // Android — satın alma kısıtlı
      case '3':
        return 'Bu cihazda satın alma işlemi kısıtlanmış.';
      // Android — zaten sahip
      case '7':
        return 'Bu aboneliğe zaten sahipsin. '
            '"Satın alımları geri yükle" butonunu kullan.';
      default:
        return 'Satın alma tamamlanamadı. '
            'Lütfen tekrar dene veya uygulamayı yeniden başlat.';
    }
  }

  int _sortIndexFor(String planId) {
    switch (planId) {
      case IapProductIds.yearly:
        return 0;
      case IapProductIds.monthly:
        return 1;
      default:
        return 99;
    }
  }
}
