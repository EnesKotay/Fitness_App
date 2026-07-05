import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/revenuecat_keys.dart';

// ─── Ürün ID'leri ─────────────────────────────────────────────────────────────
// App Store Connect / Google Play Console'daki ürün ID'leriyle ve RevenueCat
// dashboard'daki products ile eşleşmeli.

class IapProductIds {
  static const String monthly = 'premium_monthly';
  static const String yearly = 'premium_yearly';
  static const Set<String> all = {monthly, yearly};
}

// ─── Ürün modeli ──────────────────────────────────────────────────────────────

/// RevenueCat paketinden türetilen sadeleştirilmiş ürün modeli.
class IapProduct {
  /// Plan ID (`premium_monthly` / `premium_yearly`).
  final String id;

  /// Mağazadan gelen formatlı fiyat (ör. "₺149,99").
  final String price;

  /// Sayısal fiyat (indirim yüzdesi hesabı için).
  final double rawPrice;

  final String currencyCode;

  const IapProduct({
    required this.id,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });
}

// ─── Sonuç modeli ─────────────────────────────────────────────────────────────

class IapPurchaseResult {
  final bool success;
  final String? planId;
  final DateTime? expiresAt;

  /// Benzersiz mağaza işlem ID'si (RevenueCat StoreTransaction).
  final String? transactionId;

  final String? errorMessage;

  const IapPurchaseResult._({
    required this.success,
    this.planId,
    this.expiresAt,
    this.transactionId,
    this.errorMessage,
  });

  factory IapPurchaseResult.success({
    required String planId,
    DateTime? expiresAt,
    String? transactionId,
  }) => IapPurchaseResult._(
    success: true,
    planId: planId,
    expiresAt: expiresAt,
    transactionId: transactionId,
  );

  factory IapPurchaseResult.failure(String message) =>
      IapPurchaseResult._(success: false, errorMessage: message);

  factory IapPurchaseResult.canceled() =>
      const IapPurchaseResult._(success: false, errorMessage: 'canceled');

  factory IapPurchaseResult.pending() =>
      const IapPurchaseResult._(success: false, errorMessage: 'pending');
}

// ─── Servis ───────────────────────────────────────────────────────────────────

/// RevenueCat tabanlı abonelik satın alma servisi.
///
/// Akış:
///   1. `main()` içinde `await IapService.instance.init()` çağrılır.
///   2. Login sonrası `logIn(userId)` ile RevenueCat kullanıcısı eşlenir —
///      backend, RevenueCat REST API'sinden bu ID ile abonelik durumunu çeker.
///   3. `purchase(planId)` native ödeme sayfasını açar; sonuç
///      [purchaseResultStream] üzerinden gelir.
///   4. Başarılı satın alma sonrası UI backend'e "premium sync" isteği atar.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  bool _configured = false;
  bool _isLoadingProducts = false;
  List<IapProduct> _products = [];
  final Map<String, Package> _packagesByPlanId = {};
  String? _productLoadError;
  Future<void>? _initFuture;

  final _purchaseResultController =
      StreamController<IapPurchaseResult>.broadcast();
  Stream<IapPurchaseResult> get purchaseResultStream =>
      _purchaseResultController.stream;

  bool get isAvailable => _configured;
  bool get isLoadingProducts => _isLoadingProducts;
  String? get productLoadError => _productLoadError;
  List<IapProduct> get products => List.unmodifiable(_products);

  // ─── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _initFuture ??= _initialize();
    await _initFuture;
  }

  Future<void> _initialize() async {
    if (_configured) return;
    if (!Platform.isIOS && !Platform.isAndroid) {
      _productLoadError = 'Bu platformda satın alma desteklenmiyor.';
      return;
    }

    final apiKey = Platform.isIOS ? RevenueCatKeys.ios : RevenueCatKeys.android;
    if (apiKey.contains('REPLACE_ME')) {
      _productLoadError =
          'Abonelik sistemi yapılandırılmamış. '
          'Lütfen uygulamayı güncelleyip tekrar dene.';
      debugPrint(
        'IapService: RevenueCat API anahtarı eksik! '
        'revenuecat_keys.dart dosyasına anahtarı ekle '
        'veya --dart-define=REVENUECAT_IOS_API_KEY=appl_XXX geç.',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _configured = true;
      debugPrint('IapService: RevenueCat yapılandırıldı.');
      await refreshProducts();
    } catch (e) {
      debugPrint('IapService: RevenueCat configure hatası — $e');
      _productLoadError =
          'Abonelik servisi başlatılamadı. '
          'İnternet bağlantını kontrol edip uygulamayı yeniden başlat.';
      notifyListeners();
    }
  }

  /// Eski API uyumluluğu — RevenueCat'te elle kapatılacak stream yok.
  void cancelSubscription() {}

  // ─── Kullanıcı eşleme ───────────────────────────────────────────────────────

  /// Backend kullanıcı ID'sini RevenueCat app_user_id olarak eşler.
  /// Login/register sonrası çağrılmalı; backend doğrulaması bu ID'ye dayanır.
  Future<void> logIn(String userId) async {
    try {
      await init();
      if (!_configured) return;
      await Purchases.logIn(userId);
      debugPrint('IapService: RevenueCat logIn — $userId');
    } catch (e) {
      debugPrint('IapService: logIn hatası — $e');
    }
  }

  /// Logout / hesap silme sonrası RevenueCat kullanıcısını anonimleştirir.
  Future<void> logOut() async {
    try {
      if (!_configured) return;
      final isAnonymous = await Purchases.isAnonymous;
      if (!isAnonymous) await Purchases.logOut();
    } catch (e) {
      debugPrint('IapService: logOut hatası — $e');
    }
  }

  // ─── Ürünler ────────────────────────────────────────────────────────────────

  Future<void> refreshProducts() async {
    if (!_configured) {
      await init();
      if (!_configured) return;
    }

    _isLoadingProducts = true;
    _productLoadError = null;
    notifyListeners();

    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;

      _products = [];
      _packagesByPlanId.clear();

      if (offering == null || offering.availablePackages.isEmpty) {
        _productLoadError = _productUnavailableMessage();
        debugPrint(
          'IapService: current offering boş — RevenueCat dashboard\'da '
          'offering/paket tanımlı mı? Mevcut offerings: '
          '${offerings.all.keys.toList()}',
        );
        return;
      }

      for (final pkg in offering.availablePackages) {
        final planId = _planIdForPackage(pkg);
        if (planId == null || _packagesByPlanId.containsKey(planId)) continue;
        _packagesByPlanId[planId] = pkg;
        _products.add(
          IapProduct(
            id: planId,
            price: pkg.storeProduct.priceString,
            rawPrice: pkg.storeProduct.price,
            currencyCode: pkg.storeProduct.currencyCode,
          ),
        );
      }

      _products.sort(
        (a, b) => _sortIndexFor(a.id).compareTo(_sortIndexFor(b.id)),
      );

      if (_products.isEmpty) {
        _productLoadError = _productUnavailableMessage();
        debugPrint(
          'IapService: offering paketleri plan ID\'leriyle eşleşmedi — '
          '${offering.availablePackages.map((p) => p.storeProduct.identifier).toList()}',
        );
      } else {
        debugPrint(
          'IapService: ${_products.length} ürün yüklendi — '
          '${_products.map((p) => '${p.id}:${p.price}').toList()}',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('IapService: getOfferings hatası — ${e.message}');
      _products = [];
      _packagesByPlanId.clear();
      _productLoadError = _localizeError(e);
    } catch (e) {
      debugPrint('IapService: refreshProducts istisna — $e');
      _products = [];
      _packagesByPlanId.clear();
      _productLoadError =
          'Abonelik bilgileri alınamadı. '
          'İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// RevenueCat paketini bizim plan ID'mize çevirir.
  /// iOS: identifier = `premium_monthly`
  /// Android: identifier = `premium_monthly:aylik-base-plan` olabilir.
  String? _planIdForPackage(Package pkg) {
    final identifier = pkg.storeProduct.identifier;
    for (final planId in IapProductIds.all) {
      if (identifier == planId || identifier.startsWith('$planId:')) {
        return planId;
      }
    }
    // Ürün ID eşleşmezse paket tipine göre eşle (dashboard'da farklı
    // adlandırılmış ürünlere karşı güvence).
    switch (pkg.packageType) {
      case PackageType.monthly:
        return IapProductIds.monthly;
      case PackageType.annual:
        return IapProductIds.yearly;
      default:
        return null;
    }
  }

  String _productUnavailableMessage() {
    if (kDebugMode) {
      return 'Abonelik paketleri yüklenemedi. RevenueCat dashboard\'da '
          '"default" offering ve paketler tanımlı mı kontrol et.';
    }
    return 'Abonelik paketleri şu an yüklenemiyor. '
        'İnternet bağlantını kontrol edip sayfayı yenile.';
  }

  /// Ürünün mağaza fiyatını döner (ör. "₺149,99").
  /// Ürünler yüklenmemişse null döner; UI fallback fiyatı gösterir.
  String? priceFor(String planId) {
    for (final p in _products) {
      if (p.id == planId) return p.price;
    }
    return null;
  }

  // ─── Satın Alma ─────────────────────────────────────────────────────────────

  /// [planId]: `IapProductIds.monthly` veya `IapProductIds.yearly`
  ///
  /// Dönen `true`, native ödeme akışının başlatıldığı anlamına gelir.
  /// Gerçek sonuç [purchaseResultStream] üzerinden iletilir.
  Future<bool> purchase(String planId) async {
    if (!_configured || _packagesByPlanId.isEmpty) {
      await refreshProducts();
    }

    if (!_configured) {
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          _productLoadError ??
              'Mağazaya bağlanılamıyor. '
                  'İnternet bağlantını kontrol edip tekrar dene.',
        ),
      );
      return false;
    }

    final package = _packagesByPlanId[planId];
    if (package == null) {
      debugPrint(
        'IapService: "$planId" paketi bulunamadı. '
        'RevenueCat offering\'inde tanımlı mı?',
      );
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Bu abonelik paketi şu an hazır değil. '
          'Birkaç dakika bekleyip tekrar dene.',
        ),
      );
      return false;
    }

    unawaited(_performPurchase(planId, package));
    return true;
  }

  Future<void> _performPurchase(String planId, Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final entitlement = result
          .customerInfo
          .entitlements
          .active[RevenueCatKeys.premiumEntitlementId];

      if (entitlement == null) {
        // Ödeme geçti ama entitlement açılmadı — dashboard'da ürün
        // entitlement'a bağlanmamış demektir.
        debugPrint(
          'IapService: satın alma tamam ama "premium" entitlement aktif değil!',
        );
        _purchaseResultController.add(
          IapPurchaseResult.failure(
            'Ödemen alındı ancak abonelik aktive edilemedi. '
            'Lütfen "Satın alımları geri yükle" butonunu dene.',
          ),
        );
        return;
      }

      _purchaseResultController.add(
        IapPurchaseResult.success(
          planId:
              _planIdForProductIdentifier(entitlement.productIdentifier) ??
              planId,
          expiresAt: DateTime.tryParse(entitlement.expirationDate ?? ''),
          transactionId: result.storeTransaction.transactionIdentifier,
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        _purchaseResultController.add(IapPurchaseResult.canceled());
      } else if (code == PurchasesErrorCode.paymentPendingError) {
        _purchaseResultController.add(IapPurchaseResult.pending());
      } else {
        debugPrint('IapService: purchase hatası — $code / ${e.message}');
        _purchaseResultController.add(
          IapPurchaseResult.failure(_localizeError(e)),
        );
      }
    } catch (e) {
      debugPrint('IapService: purchase istisna — $e');
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alma tamamlanamadı. '
          'Lütfen tekrar dene veya uygulamayı yeniden başlat.',
        ),
      );
    }
  }

  /// Geçmiş App Store / Play Store satın almalarını geri yükler.
  Future<void> restorePurchases() async {
    if (!_configured) {
      await init();
    }
    if (!_configured) {
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alımları geri yüklemek için internet bağlantın gerekli. '
          'Lütfen bağlantını kontrol et.',
        ),
      );
      return;
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final entitlement =
          customerInfo.entitlements.active[RevenueCatKeys.premiumEntitlementId];

      if (entitlement == null) {
        _purchaseResultController.add(
          IapPurchaseResult.failure(
            'Geri yüklenecek aktif bir abonelik bulunamadı. '
            'Satın aldığın Apple/Google hesabıyla giriş yaptığından emin ol.',
          ),
        );
        return;
      }

      final planId =
          entitlement.productIdentifier.toLowerCase().contains('year')
          ? IapProductIds.yearly
          : IapProductIds.monthly;

      _purchaseResultController.add(
        IapPurchaseResult.success(
          planId: planId,
          expiresAt: DateTime.tryParse(entitlement.expirationDate ?? ''),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('IapService: restore hatası — ${e.message}');
      _purchaseResultController.add(
        IapPurchaseResult.failure(_localizeError(e)),
      );
    } catch (e) {
      debugPrint('IapService: restore istisna — $e');
      _purchaseResultController.add(
        IapPurchaseResult.failure(
          'Satın alım geçmişin yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  // ─── Hata çevirisi ──────────────────────────────────────────────────────────

  String _localizeError(PlatformException e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    switch (code) {
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.offlineConnectionError:
        return 'Ağ bağlantısı hatası. İnternetini kontrol edip tekrar dene.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Bu cihazda satın alma kısıtlanmış. '
            'Ayarlar → Ekran Süresi → İçerik ve Gizlilik Kısıtlamaları\'nı kontrol et.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Bu abonelik paketi şu an mağazada mevcut değil. '
            'Daha sonra tekrar dene.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Bu aboneliğe zaten sahipsin. '
            '"Satın alımları geri yükle" butonunu kullan.';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'Bu satın alma başka bir hesapla ilişkilendirilmiş. '
            '"Satın alımları geri yükle" butonunu dene.';
      case PurchasesErrorCode.storeProblemError:
        return 'App Store şu an yanıt vermiyor. '
            'Birkaç dakika sonra tekrar dene.';
      case PurchasesErrorCode.configurationError:
      case PurchasesErrorCode.invalidCredentialsError:
        return 'Abonelik sistemi yapılandırma hatası. '
            'Lütfen uygulamayı güncelle veya destek ekibine yaz.';
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

  String? _planIdForProductIdentifier(String productIdentifier) {
    final normalized = productIdentifier.toLowerCase();
    if (normalized.contains('year')) return IapProductIds.yearly;
    if (normalized.contains('month')) return IapProductIds.monthly;
    return null;
  }
}
