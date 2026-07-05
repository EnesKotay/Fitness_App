import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/screens/premium_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';

import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import '../services/ai_coach_usage_service.dart';
import '../services/ai_coach_sync_service.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../widgets/chat_bubble.dart';
import 'chat_history_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/constants/premium_features.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';

part 'ai_coach_screen_components.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key, this.initialSummary});
  final DailySummary? initialSummary;

  @override
  Widget build(BuildContext context) {
    final userId =
        context.read<AuthProvider?>()?.user?.id ?? StorageHelper.getUserId();
    return ChangeNotifierProvider<AiCoachController>(
      create: (_) =>
          AiCoachController(initialSummary: initialSummary, userId: userId),
      child: const AiCoachScreenBody(),
    );
  }
}

class AiCoachScreenBody extends StatefulWidget {
  const AiCoachScreenBody({super.key});
  @override
  State<AiCoachScreenBody> createState() => _AiCoachScreenBodyState();
}

class _AiCoachScreenBodyState extends State<AiCoachScreenBody>
    with WidgetsBindingObserver {
  static const Color _surface = Color(0xFF101826);
  static const Color _brandBlue = Color(0xFF73D4FF);
  static const Color _brandGold = Color(0xFFEBC374);
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final AiCoachUsageService _usageService = AiCoachUsageService();
  late ConfettiController _confettiController;
  bool _isPremium = false;
  int _remainingFreePrompts = AiCoachUsageService.freeDailyPromptLimit;
  AiCoachController? _aiController;
  bool _hasText = false;
  bool _showScrollToBottom = false;

  // V6: Voice Input integration
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  double _soundLevel = 0.0;
  bool _speechInitialized = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    try {
      // İzin kontrolü önce yap
      final permissionStatus = await Permission.microphone.request();
      if (!permissionStatus.isGranted) {
        if (mounted) {
          _showToast('Sesli komut için mikrofon izni gereklidir.');
        }
        return;
      }

      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              if (mounted) {
                setState(() => _isListening = false);
              }
            }
          },
          onError: (val) {
            if (mounted) {
              setState(() => _isListening = false);
            }
            debugPrint('Speech error: $val');
          },
        );
        if (available) {
          _speechInitialized = true;
        } else {
          if (mounted) {
            _showToast('Ses tanıma bu cihazda desteklenmiyor.');
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isListening = true;
          _soundLevel = 0.0;
        });
      }
      HapticFeedback.mediumImpact();

      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              _textController.text = val.recognizedWords;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = level);
          }
        },
        localeId: 'tr_TR',
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (mounted) {
        setState(() => _isListening = false);
        _showToast('Ses tanıma başlatılamadı. Gerçek cihazda deneyin.');
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
    HapticFeedback.lightImpact();
  }

  Widget _buildVoiceEqualizer() {
    // soundLevel typically goes from -2 to 10+, let's normalize to a 0.0 - 1.0 range
    final normalized = ((_soundLevel + 2.0) / 12.0).clamp(0.0, 1.0);
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          // Add some variation per bar to make it look like a real equalizer
          final multipliers = [0.4, 0.9, 0.6, 0.8, 0.5];
          final heightMultiplier = multipliers[index];
          // Each bar scales with normalized sound level
          final barHeight = 3.0 + (normalized * 15.0 * heightMultiplier);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 3.5,
            height: barHeight,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4444), Color(0xFFFF8888)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '🤖',
      title: 'Kişisel AI Asistanın',
      description:
          'Bu ekran senin 7/24 hizmetindeki kişisel fitness ve beslenme koçundur.\n\n'
          'Sadece genel geçer bilgiler değil, doğrudan senin mevcut kilona, hedefine ve gün içindeki kalori verilerine bakarak sana özel tavsiyeler verir.',
      tip:
          'AI asistanın Türkçe dilinde uzmandır, cümleleri tam kurmasan bile ne demek istediğini anlar.',
    ),
    GuideStep(
      emoji: '💬',
      title: 'Neler Sorabilirsin?',
      description:
          'Her türlü konuda yardım isteyebilirsin:\n\n'
          '• Antrenman Programı: "Bana 3 günlük tüm vücut ağırlık programı ver"\n'
          '• Yemek Planı: "Kalan 500 kalorim için bol proteinli bir akşam yemeği öner"\n'
          '• Bilgi & Sorular: "Kreatin ne zaman kullanılmalı?"\n'
          '• Psikolojik Destek: "Bugün antrenmana gitmeye üşeniyorum, beni motive et"',
      tip:
          'Eğer bir antrenman programı veya tarif istersen, AI bunu senin için okunaklı liste halinde sunar.',
    ),
    GuideStep(
      emoji: '📊',
      title: 'Veri Entegrasyonu',
      description:
          'AI Koç, uygulamanın geri kalanıyla bağlantılıdır.\n\n'
          '"Bugün nasılım?" veya "Diyetime uyuyor muyum?" diye sorduğunda o gün yediğin kalorilere, attığın adımlara ve su tüketimine bakar ve sana durum değerlendirmesi yapar.',
      tip:
          'Gece uyumadan önce "Bana günümün özetini yap" diyerek gidişatını kontrol edebilirsin.',
    ),
    GuideStep(
      emoji: '📷',
      title: 'Görsel Analiz (Fotoğraf)',
      description:
          'Yazı kutusunun yanındaki artı/kamera (➕) ikonuna dokunarak yemeğinin fotoğrafını gönderebilirsin.\n\n'
          'AI görüntüyü analiz eder, tabağındaki yiyecekleri tespit eder ve sana tahmini kalori ile protein, karb, yağ değerlerini söyler.',
      tip:
          'Dışarıda yemek yerken porsiyonu bilemediğinde fotoğraf çekip sormak hayat kurtarır.',
    ),
    GuideStep(
      emoji: '🔁',
      title: 'Bağlamı Hatırlama',
      description:
          'AI ile arandaki sohbet devamlıdır. Önceki dediklerini unutmaz.\n\n'
          'Örneğin sana bir yemek planı verdiğinde; "Bu plandaki tavuğu çıkarıp yerine balık koy" dersen, önceki planı anlar ve sadece istediğin kısmı güncelleyerek yeniden sunar.',
      tip:
          'Sohbet geçmişin kaydedilir. Ücretsiz sürümde mesaj hakkın sınırlıdır (tepe noktasında gösterilir).',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('ai_coach')) return;
    await PageGuideService.markGuideSeen('ai_coach');
    if (mounted) await _showGuide();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      final position = _scrollController.position;
      final distanceFromBottom = position.maxScrollExtent - position.pixels;

      if (bottom > 100 && distanceFromBottom < 120) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadAccessState();
      if (mounted) {
        _aiController = context.read<AiCoachController>();
        _aiController!.addListener(_onAiControllerUpdate);
        // Rehberi önce göster; oturum ve bildirimler arka planda yüklensin
        await _checkFirstVisitGuide();
        if (!mounted) return;
        await _aiController!.restoreSession();
        if (mounted) {
          context.read<NotificationService>().fetchNotifications();
        }
      }
    });

    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      final len = _textController.text.length;
      if (hasText != _hasText || len > 80) {
        setState(() => _hasText = hasText);
      }
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final show =
          _scrollController.offset <
          _scrollController.position.maxScrollExtent - 250;
      if (show != _showScrollToBottom) {
        setState(() => _showScrollToBottom = show);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiController?.removeListener(_onAiControllerUpdate);
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _confettiController.dispose();
    _speech.cancel(); // Speech service'i temizle
    super.dispose();
  }

  void _onAiControllerUpdate() {
    if (!mounted) return;
    final serverRemaining = _aiController?.serverRemainingFreePrompts;
    if (!_isPremium &&
        serverRemaining != null &&
        serverRemaining != _remainingFreePrompts) {
      setState(() => _remainingFreePrompts = serverRemaining);
    }

    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Kullanıcı en alttaysa (300px içindeyse) otomatik scroll yap
    if (pos.maxScrollExtent - pos.pixels < 300) {
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadAccessState() async {
    final auth = context.read<AuthProvider?>();
    final user = auth?.user;
    var isPremium = isPremiumTier(
      user?.premiumTier,
      expiresAt: user?.premiumExpiresAt,
    );

    if (!isPremium) {
      try {
        final aiService = context.read<DietProvider>().aiService;
        if (aiService != null) {
          final remotePremium = await aiService.checkPremiumStatus();
          if (remotePremium != null) {
            isPremium = remotePremium;
            if (auth != null) {
              auth.setPremiumActive(remotePremium);
            }
          }
        }
      } catch (e) {
        debugPrint('AiCoachScreen: premium kontrol hatası: $e');
      }
    }

    _syncUserData();

    int? serverRemaining;
    if (!isPremium) {
      try {
        serverRemaining = await _usageService.getServerRemainingFreePrompts();
        if (serverRemaining != null && user != null) {
          await _usageService.setRemainingFreePrompts(
            userId: user.id,
            remaining: serverRemaining,
          );
        }
      } catch (e) {
        debugPrint('AiCoachScreen: kota kontrol hatası: $e');
      }
    }

    final localRemaining = isPremium
        ? AiCoachUsageService.freeDailyPromptLimit
        : (user != null
              ? await _usageService.getRemainingFreePrompts(userId: user.id)
              : 0);

    if (mounted) {
      final controller = context.read<AiCoachController?>();
      if (serverRemaining != null) {
        controller?.updateFromServerQuota(serverRemaining);
      }
      setState(() {
        _isPremium = isPremium;
        _remainingFreePrompts =
            serverRemaining ??
            controller?.serverRemainingFreePrompts ??
            localRemaining;
      });
    }
  }

  Future<void> _syncUserData() async {
    await AiCoachSyncService.syncUserData(context);
  }

  void _showFreeLimitSheet() {
    final controller = context.read<AiCoachController>();
    final teaser = _buildLimitTeaser(controller);
    final nextStep = _buildLimitNextStep(controller);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF111318),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _brandGold.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _brandGold.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İkon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brandGold.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _brandGold.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: _brandGold,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Günlük hakkın doldu',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ücretsiz planda bugünkü 2 sorunu kullandın.\nYarın Gemini hakkın sıfırlanır, Premium\'da ise Claude ile sınırsız devam edersin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151B24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          color: Color(0xFF73D4FF),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Şu anki verin ne söylüyor?',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      teaser,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextStep,
                      style: GoogleFonts.dmSans(
                        color: _brandGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Premium avantajları
              _LimitSheetFeature(
                icon: Icons.smart_toy_rounded,
                label: 'Claude ile daha derin ve sınırsız koçluk',
                color: _brandGold,
              ),
              const SizedBox(height: 10),
              _LimitSheetFeature(
                icon: Icons.insights_rounded,
                label: 'Verilerini plana dönüştüren gelişmiş analiz',
                color: const Color(0xFF64B5F6),
              ),
              const SizedBox(height: 10),
              _LimitSheetFeature(
                icon: Icons.restaurant_menu_rounded,
                label: 'Hazır öğün planı ve otomatik alışveriş listesi',
                color: const Color(0xFF81C784),
              ),
              const SizedBox(height: 24),
              // Premium butonu
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _brandGold.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PremiumScreen(),
                          ),
                        );
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_open_rounded,
                              size: 17,
                              color: Color(0xFF1A0F00),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Premium\'a Geç — Sınırsız Kullan',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF1A0F00),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Yarın devam et butonu
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Yarın devam edeceğim',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildLimitTeaser(AiCoachController controller) {
    final s = controller.dailySummary;
    final parts = <String>[];

    if (s.targetCalories != null && s.calories > 0) {
      final diff = s.targetCalories! - s.calories;
      if (diff > 150) {
        parts.add('Bugün kalori hedefinin yaklaşık $diff kcal altındasın.');
      } else if (diff < -150) {
        parts.add(
          'Bugün hedefini yaklaşık ${diff.abs()} kcal aşmış görünüyorsun.',
        );
      } else {
        parts.add('Bugün kalori hedefine oldukça yakınsın.');
      }
    } else if (s.calories > 0) {
      parts.add('Bugün ${s.calories} kcal kayıt girdin.');
    }

    if (s.proteinGrams != null && s.proteinGrams! > 0) {
      parts.add('Protein alımın ${s.proteinGrams} g seviyesinde.');
    }

    if (s.waterLiters > 0) {
      parts.add('${s.waterLiters.toStringAsFixed(1)} L su içtin.');
    }

    if (s.workouts > 0) {
      parts.add('${s.workouts} antrenman kaydın var.');
    }

    if (parts.isEmpty) {
      return 'Bugün henüz pek veri girmemişsin. Premium ile Claude, hedefin olan ${controller.goal.label.toLowerCase()} için doğrudan bir adım planı çizebilirdi.';
    }

    return parts.take(2).join(' ');
  }

  String _buildLimitNextStep(AiCoachController controller) {
    final s = controller.dailySummary;
    String claudeQuote = '';

    if (s.targetCalories != null && s.calories > 0) {
      final diff = s.targetCalories! - s.calories;
      if (diff > 150) {
        claudeQuote =
            '«Kalori açığın güzel ama kas kaybını önlemek için şu an $diff kalorilik yüksek proteinli şu öğünü eklemelisin...»';
      } else if (diff < -150) {
        claudeQuote =
            '«Hedefi biraz aştık. Yarınki kardiyoyu 15 dk uzatıp ilk öğünde karbonhidratı kısarak bunu hızla dengeleyelim...»';
      } else {
        claudeQuote =
            '«Tam hedeftesin. Yarın bu dengeyi korumak için sana şu 3 öğünlük makro planını hazırladım...»';
      }
    } else if (s.workouts > 0) {
      claudeQuote =
          '«Bugünkü idman yüküne göre yarınki dinlenme stratejin böyle olmalı. Toparlanmayı hızlandıracak rutinin şudur...»';
    } else if (s.mealNames.isNotEmpty) {
      claudeQuote =
          '«Bugün yediklerine baktığımda protein dağılımında şu eksik var, yarınki öğününe doğrudan şunu ekleyelim...»';
    } else {
      claudeQuote =
          '«Hedefine ulaşman için yarın sabah kalktığında uygulaman gereken ilk 3 adım şunlar...»';
    }

    return 'Premium açık olsaydı, Claude sana şu an muhtemelen şunu derdi:\n\n$claudeQuote';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _handleSend(AiCoachController controller) async {
    final text = _textController.text.trim();
    if (text.isEmpty || controller.isLoading) return;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    final hadConversation = controller.messages.any(
      (message) => message.role == ChatRole.user && !message.isError,
    );

    if (!StorageHelper.getPrivacyTransferConsent()) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yurt Dışı Aktarım Rızası Gerekli'),
          content: const Text(
            'AI koç özelliği, verilerinizin Google Gemini (ABD) sunucularına '
            'aktarılmasını gerektirir. Bu özelliği kullanmak için '
            'Ayarlar → Gizlilik → Yurt dışı aktarım rızasını açmanız gerekiyor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).pushNamed('/settings-privacy');
                if (mounted) setState(() {});
              },
              child: const Text('Rızayı Aç'),
            ),
          ],
        ),
      );
      return;
    }

    if (!_isPremium && _remainingFreePrompts <= 0) {
      _showFreeLimitSheet();
      return;
    }

    HapticFeedback.lightImpact();
    _textController.clear();
    _inputFocusNode.requestFocus();
    final success = await controller.submitPrompt(text);
    if (!mounted) return;

    if (success) {
      // Sync with DailyTasksController
      final dailyTasks = context.read<DailyTasksController>();
      final lastMsg = controller.messages.last;
      if (lastMsg.role == ChatRole.assistant &&
          lastMsg.structuredResponse != null) {
        for (var item in lastMsg.structuredResponse!.todoItems) {
          await dailyTasks.addFromAiAction(item);
          if (!mounted) return;
        }
      }
    }

    if (!_isPremium) {
      final auth = context.read<AuthProvider?>();
      final user = auth?.user;
      final serverRemaining = controller.serverRemainingFreePrompts;
      if (user != null) {
        if (serverRemaining != null) {
          await _usageService.setRemainingFreePrompts(
            userId: user.id,
            remaining: serverRemaining,
          );
          if (mounted) {
            setState(() => _remainingFreePrompts = serverRemaining);
          }
        } else if (success) {
          await _usageService.incrementPromptCount(userId: user.id);
        }
      }
      if (success && mounted) {
        _loadAccessState();
      }
    }

    if (hadConversation) {
      _scrollToBottom();
    }
  }

  void _applyPrompt(AiCoachController controller, String prompt) {
    HapticFeedback.selectionClick();
    _textController.text = prompt;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
    // Chip'e basınca direkt gönder — kullanıcı edit etmek isterse zaten klavye açılır
    _handleSend(controller);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiCoachController>(
      builder: (context, controller, _) {
        if (!controller.isSessionRestored) {
          return const Scaffold(
            backgroundColor: Color(0xFF070B16),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFEBC374)),
            ),
          );
        }

        final hasUserMessage = controller.messages.any(
          (message) => message.role == ChatRole.user && !message.isError,
        );
        final hasAssistantReply = controller.messages.any(
          (message) =>
              message.role == ChatRole.assistant &&
              !message.id.startsWith('welcome_') &&
              !message.isThinking &&
              !message.isError,
        );
        final firstTurnInFlight =
            hasUserMessage && controller.isLoading && !hasAssistantReply;
        final hasConversation = hasUserMessage && !firstTurnInFlight;
        final visibleMessages = controller.messages
            .where((message) => !message.id.startsWith('welcome_'))
            .toList();
        // Step: Confetti Trigger
        if (controller.shouldShowConfetti) {
          _confettiController.play();
          HapticFeedback.heavyImpact();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.resetConfetti();
          });
        }

        final hasTransferConsent = StorageHelper.getPrivacyTransferConsent();

        return Scaffold(
          backgroundColor: const Color(0xFF070B16),
          appBar: _buildAppBar(controller),
          body: Stack(
            children: [
              const _AnimatedMeshBackground(),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (!hasTransferConsent)
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed('/settings-privacy'),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1A1200).withValues(alpha: 0.95),
                                const Color(0xFF251800).withValues(alpha: 0.95),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: const Color(
                                0xFFD89A6A,
                              ).withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFCC7A4A,
                                ).withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD89A6A,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFFD89A6A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Koç kapalı',
                                      style: TextStyle(
                                        color: Color(0xFFE8B882),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Kullanmak için gizlilik iznini etkinleştir.',
                                      style: TextStyle(
                                        color: Color(0xFFAA8866),
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD89A6A,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD89A6A,
                                    ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Aç',
                                  style: TextStyle(
                                    color: Color(0xFFD89A6A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            children: [
                              if (!hasConversation) ...[
                                if (firstTurnInFlight)
                                  _buildFirstTurnInFlight(controller)
                                else
                                  _buildStartExperience(controller),
                              ] else ...[
                                _buildCompactConversationHeader(controller),
                              ],
                              const SizedBox(height: 6),
                              if (!firstTurnInFlight)
                                ...visibleMessages.map(
                                  (message) => ChatBubble(message: message)
                                      .animate()
                                      .fadeIn(
                                        duration: 250.ms,
                                        curve: Curves.easeOutCubic,
                                      )
                                      .slideY(
                                        begin: 0.08,
                                        end: 0,
                                        duration: 350.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                                ),
                              if (visibleMessages.isNotEmpty &&
                                  visibleMessages.last.isError &&
                                  controller.canRetryLastPrompt) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        controller.retryLastPrompt(),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: Color(0xFFEBC374),
                                    ),
                                    label: Text(
                                      'Tekrar dene',
                                      style: GoogleFonts.dmSans(
                                        color: const Color(0xFFEBC374),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (hasConversation &&
                                  !controller.isLoading &&
                                  !firstTurnInFlight) ...[
                                const SizedBox(height: 8),
                                _buildActionChipStrip(controller),
                              ],
                            ],
                          ),
                          if (_showScrollToBottom)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child:
                                  FloatingActionButton.small(
                                        heroTag:
                                            'ai_coach_scroll_to_bottom_fab',
                                        backgroundColor: const Color(
                                          0xFF1F2937,
                                        ).withValues(alpha: 0.9),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        onPressed: _scrollToBottom,
                                        child: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 200.ms)
                                      .scale(curve: Curves.easeOutBack),
                            ),
                        ],
                      ),
                    ),
                    _buildInputSection(controller),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFEBC374),
                    Color(0xFFBC74EB),
                    Colors.white,
                  ],
                  numberOfParticles: 30,
                  gravity: 0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AiCoachController controller) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.black.withValues(alpha: 0.16)),
        ),
      ),
      title: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 250;
          final accent = _isPremium ? _brandGold : _brandBlue;
          final subtitle = _isPremium
              ? '${controller.taskMode.label} · ${_personalityShortLabel(controller.personality)}'
              : '${controller.taskMode.label} · $_remainingFreePrompts hak kaldı';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'AI Koç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 18 : 19,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: Text(
                      _isPremium ? 'Premium' : 'Free',
                      style: GoogleFonts.dmSans(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEBC374),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(child: PageGuideButton(onTap: _showGuide)),
        ),
        IconButton(
          icon: Consumer<NotificationService>(
            builder: (context, ns, _) => Badge(
              isLabelVisible: ns.unreadCount > 0,
              label: Text(
                ns.unreadCount.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          tooltip: 'Bildirimler',
          onPressed: () => _showNotifications(context),
        ),
        PopupMenuButton<String>(
          tooltip: 'AI Koç ayarları',
          color: const Color(0xFF0F1528),
          elevation: 16,
          offset: const Offset(0, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          constraints: const BoxConstraints(minWidth: 276),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: Colors.white.withValues(alpha: 0.82),
              size: 18,
            ),
          ),
          onSelected: (value) async {
            if (value == 'goal') {
              _showGoalPicker(context, controller);
            } else if (value == 'personality') {
              _showPersonalityPicker(context, controller);
            } else if (value == 'new') {
              await controller.startNewConversation();
            } else if (value == 'history') {
              final reload = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ChatHistoryScreen(controller: controller),
                ),
              );
              if (reload == true && mounted) setState(() {});
            } else if (value == 'regenerate') {
              await controller.retryLastPrompt();
            } else if (value == 'clear') {
              controller.clearMessages();
            } else if (value == 'memory') {
              Navigator.of(context).pushNamed('/ai-memory');
            } else if (value == 'premium') {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
            }
          },
          itemBuilder: (context) => [
            _coachMenuHeader(),
            _coachMenuItem(
              value: 'new',
              icon: Icons.add_comment_rounded,
              iconColor: _brandBlue,
              title: 'Yeni Sohbet',
            ),
            _coachMenuItem(
              value: 'history',
              icon: Icons.history_rounded,
              iconColor: _brandGold,
              title: 'Sohbet Geçmişi',
            ),
            _coachMenuSection('Kişiselleştirme'),
            _coachMenuItem(
              value: 'goal',
              icon: Icons.flag_rounded,
              iconColor: const Color(0xFF9CA3AF),
              title: 'Hedef seç',
            ),
            _coachMenuItem(
              value: 'personality',
              icon: Icons.record_voice_over_rounded,
              iconColor: const Color(0xFF9CA3AF),
              title: 'Koç karakteri',
            ),
            _coachMenuItem(
              value: 'memory',
              icon: Icons.psychology_rounded,
              iconColor: _brandGold,
              title: 'AI Hafızası',
            ),
            _coachMenuSection('Sohbet araçları'),
            _coachMenuItem(
              value: 'regenerate',
              enabled:
                  controller.canRetryLastPrompt &&
                  controller.messages.length > 2,
              icon: Icons.refresh_rounded,
              iconColor: const Color(0xFF9CA3AF),
              title: 'Son Cevabı Yeniden Üret',
            ),
            _coachMenuItem(
              value: 'clear',
              icon: Icons.delete_sweep_rounded,
              iconColor: const Color(0xFFF87171),
              title: 'Sohbeti Temizle',
              destructive: true,
            ),
            if (!_isPremium) ...[
              _coachMenuSection('Premium'),
              _coachMenuItem(
                value: 'premium',
                icon: Icons.stars_rounded,
                iconColor: _brandGold,
                title: "Premium'u aç",
                emphasized: true,
              ),
            ],
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuEntry<String> _coachMenuHeader() {
    return PopupMenuItem<String>(
      enabled: false,
      height: 52,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _brandBlue.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _brandBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Koç',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuEntry<String> _coachMenuSection(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 34,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            Container(
              height: 1,
              width: 86,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _coachMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    bool enabled = true,
    bool emphasized = false,
    bool destructive = false,
  }) {
    final textColor = enabled
        ? (destructive
              ? const Color(0xFFFFA3A3)
              : emphasized
              ? _brandGold
              : Colors.white.withValues(alpha: 0.92))
        : Colors.white.withValues(alpha: 0.38);
    final effectiveIconColor = enabled
        ? iconColor
        : Colors.white.withValues(alpha: 0.34);
    final tileColor = emphasized
        ? _brandGold.withValues(alpha: 0.08)
        : Colors.transparent;

    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: emphasized
              ? Border.all(color: _brandGold.withValues(alpha: 0.14))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(
                  alpha: enabled ? 0.13 : 0.06,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: effectiveIconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildContextLine(AiCoachController controller) {
    final s = controller.dailySummary;
    final parts = <String>[];
    if (s.calories > 0) parts.add('${s.calories} kcal');
    if (s.waterLiters > 0) {
      parts.add('${s.waterLiters.toStringAsFixed(1)} L su');
    }
    if (s.workouts > 0) {
      parts.add(
        '${s.workouts} antrenman${s.workoutMinutes > 0 ? ' (${s.workoutMinutes} dk)' : ''}',
      );
    }
    if (parts.isEmpty) {
      return 'Bugün kayıt yok; veriler geldikçe öneriler netleşir.';
    }
    return 'Bugün: ${parts.join(' · ')}';
  }

  List<(IconData, String, Color)> _buildInsightItems(
    AiCoachController controller,
  ) {
    final s = controller.dailySummary;
    final items = <(IconData, String, Color)>[];

    if (s.targetCalories != null && s.calories > 0) {
      final diff = s.calories - s.targetCalories!;
      if (diff.abs() <= 150) {
        items.add((
          Icons.track_changes_rounded,
          'Kalori çizgide',
          const Color(0xFF34D399),
        ));
      } else if (diff > 150) {
        items.add((
          Icons.local_fire_department_rounded,
          '${diff.abs()} kcal fazla',
          const Color(0xFFFF8A65),
        ));
      } else {
        items.add((
          Icons.restaurant_rounded,
          '${diff.abs()} kcal alan var',
          const Color(0xFFEBC374),
        ));
      }
    }

    if (s.avgWaterLast7Days != null && s.waterLiters > 0) {
      if (s.waterLiters < s.avgWaterLast7Days!) {
        items.add((
          Icons.water_drop_rounded,
          'Su ortalamanın altında',
          const Color(0xFF73D4FF),
        ));
      } else {
        items.add((
          Icons.water_rounded,
          'Su iyi gidiyor',
          const Color(0xFF4FACFE),
        ));
      }
    } else if (s.waterLiters < 1.0) {
      items.add((
        Icons.opacity_rounded,
        'Su için alan var',
        const Color(0xFF73D4FF),
      ));
    }

    if (s.workouts == 0) {
      items.add((
        Icons.self_improvement_rounded,
        'Hareket ekle',
        const Color(0xFFA78BFA),
      ));
    } else if (s.workoutMinutes >= 45) {
      items.add((
        Icons.fitness_center_rounded,
        'Toparlanma önemli',
        const Color(0xFF34D399),
      ));
    }

    if ((s.bmi ?? 0) > 0) {
      items.add((
        Icons.monitor_weight_rounded,
        'BMI ${s.bmi!.toStringAsFixed(1)}',
        const Color(0xFFBC74EB),
      ));
    }

    return items.take(4).toList();
  }

  (IconData, Color) _chipMeta(String chip, CoachTaskMode mode) {
    final lc = chip.toLowerCase();
    if (lc.contains('kalori') ||
        lc.contains('kcal') ||
        lc.contains('öğün') ||
        lc.contains('yemek') ||
        lc.contains('kahvaltı')) {
      return (Icons.restaurant_rounded, const Color(0xFFEBC374));
    }
    if (lc.contains('antrenman') ||
        lc.contains('egzersiz') ||
        lc.contains('hareket')) {
      return (Icons.fitness_center_rounded, const Color(0xFF34D399));
    }
    if (lc.contains('su') ||
        lc.contains('toparlanma') ||
        lc.contains('uyku') ||
        lc.contains('dinlen')) {
      return (Icons.water_drop_rounded, const Color(0xFF73D4FF));
    }
    if (lc.contains('analiz') ||
        lc.contains('özet') ||
        lc.contains('nasıl') ||
        lc.contains('veriler')) {
      return (Icons.insights_rounded, const Color(0xFFBC74EB));
    }
    if (lc.contains('plan') ||
        lc.contains('öncelik') ||
        lc.contains('program')) {
      return (Icons.route_rounded, const Color(0xFF6B9FFF));
    }
    if (lc.contains('makro') ||
        lc.contains('protein') ||
        lc.contains('beslen')) {
      return (Icons.pie_chart_rounded, const Color(0xFFEBC374));
    }
    return switch (mode) {
      CoachTaskMode.nutrition => (
        Icons.restaurant_rounded,
        const Color(0xFFEBC374),
      ),
      CoachTaskMode.workout => (
        Icons.fitness_center_rounded,
        const Color(0xFF34D399),
      ),
      CoachTaskMode.recovery => (
        Icons.self_improvement_rounded,
        const Color(0xFF73D4FF),
      ),
      CoachTaskMode.analysis => (
        Icons.analytics_rounded,
        const Color(0xFFBC74EB),
      ),
      CoachTaskMode.plan => (Icons.route_rounded, const Color(0xFF6B9FFF)),
    };
  }

  IconData _modeIcon(CoachTaskMode mode) {
    switch (mode) {
      case CoachTaskMode.plan:
        return Icons.route_rounded;
      case CoachTaskMode.nutrition:
        return Icons.restaurant_menu_rounded;
      case CoachTaskMode.workout:
        return Icons.fitness_center_rounded;
      case CoachTaskMode.recovery:
        return Icons.self_improvement_rounded;
      case CoachTaskMode.analysis:
        return Icons.analytics_rounded;
    }
  }

  Widget _buildStartExperience(AiCoachController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroCard(controller),
        const SizedBox(height: 12),
        _buildStarterPromptSection(controller),
      ],
    );
  }

  Widget _buildFirstTurnInFlight(AiCoachController controller) {
    final userPrompts = controller.messages
        .where((message) => message.role == ChatRole.user && !message.isError)
        .toList();
    final prompt = userPrompts.isNotEmpty ? userPrompts.last.content : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroCard(controller),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1726).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: _brandBlue.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: Color(0xFF73D4FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cevap hazırlanıyor',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Yanıt birazdan burada görünecek.',
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (prompt.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _brandBlue.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    prompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brandGold.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Analiz ediliyor',
                    style: GoogleFonts.dmSans(
                      color: _brandGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStarterPromptSection(AiCoachController controller) {
    return _buildStarterPromptGrid(controller);
  }

  String _personalityShortLabel(CoachPersonality personality) {
    return switch (personality) {
      CoachPersonality.motivator => 'Disiplinli',
      CoachPersonality.scientist => 'Bilimsel',
      CoachPersonality.supportive => 'Destekleyici',
    };
  }

  Widget _buildIntroMetaPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _metricChipPrompt(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('kalori') || lower.contains('kcal')) {
      return 'Bugünkü kalori ve beslenme verilerimi analiz eder misin?';
    }
    if (lower.contains('su')) {
      return 'Bugünkü su tüketimimi yorumlar mısın? Yeterli mi?';
    }
    if (lower.contains('hareket') ||
        lower.contains('antrenman') ||
        lower.contains('toparlanma')) {
      return 'Bugünkü hareket ve aktivite durumumu değerlendirir misin?';
    }
    if (lower.contains('bmi')) {
      return 'BMI değerimi yorumlayıp benim için ideal kilo hedeflerini açıklar mısın?';
    }
    return 'Bugünkü durumumu analiz edip bir plan önerir misin?';
  }

  Widget _buildIntroCard(AiCoachController controller) {
    final modelLabel = _isPremium ? 'Claude' : 'Gemini Flash';
    final modelColor = _isPremium
        ? const Color(0xFFEBC374)
        : const Color(0xFF73D4FF);
    final modelIcon = _isPremium
        ? Icons.stars_rounded
        : Icons.auto_awesome_rounded;

    final rawName = context.read<AuthProvider?>()?.user?.name ?? '';
    final userName = rawName.isNotEmpty ? rawName.split(' ').first : null;
    final hour = DateTime.now().hour;
    final timeGreeting = hour >= 5 && hour < 12
        ? 'Günaydın'
        : hour >= 12 && hour < 17
        ? 'Merhaba'
        : hour >= 17 && hour < 22
        ? 'İyi akşamlar'
        : 'İyi geceler';
    final greeting = userName != null && userName.isNotEmpty
        ? '$timeGreeting, $userName!'
        : '$timeGreeting!';
    final contextLine = _buildContextLine(controller);
    final insights = _buildInsightItems(controller);
    final personalityLabel = _personalityShortLabel(controller.personality);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF162133).withValues(alpha: 0.98),
            const Color(0xFF0C1321).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: modelColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      modelColor.withValues(alpha: 0.22),
                      modelColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: modelColor.withValues(alpha: 0.24)),
                ),
                child: Icon(modelIcon, size: 19, color: modelColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Koç hazır',
                      style: GoogleFonts.dmSans(
                        color: modelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Bugünkü plan, analiz ve öneriler burada.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: modelColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: modelColor.withValues(alpha: 0.22)),
                ),
                child: Text(
                  modelLabel,
                  style: GoogleFonts.dmSans(
                    color: modelColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timeline_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contextLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildIntroMetaPill(
                icon: _modeIcon(controller.taskMode),
                label: controller.taskMode.label,
                color: _brandBlue,
              ),
              _buildIntroMetaPill(
                icon: Icons.record_voice_over_rounded,
                label: personalityLabel,
                color: const Color(0xFFBC74EB),
              ),
              _buildIntroMetaPill(
                icon: modelIcon,
                label: modelLabel,
                color: modelColor,
              ),
            ],
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: insights
                      .take(3)
                      .map(
                        (item) => InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _applyPrompt(
                              controller,
                              _metricChipPrompt(item.$2),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item.$3.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: item.$3.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: item.$3.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    item.$1,
                                    size: 12,
                                    color: item.$3,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactConversationHeader(AiCoachController controller) {
    final summary = controller.dailySummary;
    final chips = <String>[];
    if (summary.calories > 0) chips.add('${summary.calories} kcal');
    if (summary.waterLiters > 0) {
      chips.add('${summary.waterLiters.toStringAsFixed(1)} L su');
    }
    if (summary.workouts > 0) chips.add('${summary.workouts} antrenman');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _brandBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _modeIcon(controller.taskMode),
                          size: 13,
                          color: _brandBlue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          controller.taskMode.label,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        chips.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarterPromptGrid(AiCoachController controller) {
    final prompts = [
      (
        label: 'Planla',
        subtitle: 'Bugünü sıraya koy',
        prompt: 'Bugün için kısa, net ve uygulanabilir bir plan hazırla.',
        icon: Icons.route_rounded,
        color: const Color(0xFF73D4FF),
      ),
      (
        label: 'Beslenme',
        subtitle: 'Öğün ve makro öner',
        prompt: 'Kalan makrolarım için pratik bir öğün öner.',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFEBC374),
      ),
      (
        label: 'Antrenman',
        subtitle: 'Seansı yorumla',
        prompt: 'Son antrenmanımı analiz et.',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF34D399),
      ),
      (
        label: 'Analiz',
        subtitle: 'Gidişatı oku',
        prompt: 'Hedefime göre haftalık plan hazırla.',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFFBC74EB),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEBC374).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tips_and_updates_rounded,
                size: 14,
                color: Color(0xFFEBC374),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Hızlı başlangıç',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: prompts.map((item) {
                return SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _applyPrompt(controller, item.prompt);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 74,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, size: 17, color: item.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionChipStrip(AiCoachController controller) {
    final chips = controller.actionChips;
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 6),
              Text(
                'Devam et',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: chips.map((chip) {
              final meta = _chipMeta(chip, controller.taskMode);
              final chipIcon = meta.$1;
              final chipColor = meta.$2;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _applyPrompt(controller, chip);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: chipColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(chipIcon, size: 13, color: chipColor),
                      const SizedBox(width: 6),
                      Text(
                        chip,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(AiCoachController controller) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 16,
                  spreadRadius: -5,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.isCooldownActive) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBC374).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEBC374).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: Color(0xFFEBC374),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${controller.cooldownSecondsRemaining ?? 0}s sonra tekrar deneyebilirsin',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFFEBC374),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isPremium && _remainingFreePrompts == 1) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEBC374).withValues(alpha: 0.12),
                            const Color(0xFFC88934).withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEBC374).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: Color(0xFFEBC374),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Son ücretsiz hak. Premium ile sınırsız devam et.',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFFEBC374),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFFEBC374),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (controller.selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(controller.selectedImage!.path),
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: GestureDetector(
                            onTap: () => controller.setSelectedImage(null),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cancel,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isListening) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4444),
                                shape: BoxShape.circle,
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 0.8, end: 1.3, duration: 600.ms),
                        const SizedBox(width: 8),
                        Text(
                          'Dinleniyor...',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFFFF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildVoiceEqualizer(),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _surface.withValues(alpha: 0.95),
                        _surface.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: controller.isLoading
                          ? _brandGold.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.11),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: -8,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: controller.isLoading
                            ? _brandGold.withValues(alpha: 0.1)
                            : Colors.transparent,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: IconButton(
                          icon: Icon(
                            controller.selectedImage != null
                                ? Icons.image_rounded
                                : Icons.add_photo_alternate_outlined,
                            color: controller.selectedImage != null
                                ? _brandGold
                                : Colors.white.withValues(alpha: 0.34),
                            size: 18,
                          ),
                          onPressed: () => _pickImage(context, controller),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // V6: Microphone Voice Input Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFFF4444).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: _isListening
                                ? const Color(0xFFFF4444).withValues(alpha: 0.4)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF4444,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 10 + (_soundLevel * 4),
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListening
                                ? const Color(0xFFFF4444)
                                : Colors.white.withValues(alpha: 0.34),
                            size: 18,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _textController,
                              focusNode: _inputFocusNode,
                              minLines: 1,
                              maxLines: 4,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                hintText: controller.isCooldownActive
                                    ? 'Bekleniyor...'
                                    : !_isPremium && _remainingFreePrompts <= 1
                                    ? 'Son hakkın, iyi kullan'
                                    : controller.taskMode.hint,
                                hintStyle: GoogleFonts.dmSans(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 13.5,
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(
                                  0,
                                  10,
                                  8,
                                  10,
                                ),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _handleSend(controller),
                            ),
                            if (_textController.text.length > 80)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 4,
                                  right: 4,
                                ),
                                child: Text(
                                  '${_textController.text.length}/500',
                                  style: TextStyle(
                                    color: _textController.text.length > 450
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white.withValues(alpha: 0.28),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildSendButton(controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(
    BuildContext context,
    AiCoachController controller,
  ) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0F1528),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFEBC374)),
              title: Text(
                'Kamerayı Aç',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFEBC374),
              ),
              title: Text(
                'Galeriden Seç',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        controller.setSelectedImage(image);
      }
    }
  }

  void _showNotifications(BuildContext context) {
    final ns = context.read<NotificationService>();
    ns.fetchNotifications();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1528),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI TAVSİYELERİ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer<NotificationService>(
                  builder: (context, ns, _) {
                    if (ns.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (ns.notifications.isEmpty) {
                      return Center(
                        child: Text(
                          'Henüz bir tavsiye yok.',
                          style: GoogleFonts.dmSans(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: ns.notifications.length,
                      itemBuilder: (context, index) {
                        final n = ns.notifications[index];
                        return Card(
                              color: n.isRead
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(
                                      0xFFEBC374,
                                    ).withValues(alpha: 0.1),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: n.isRead
                                      ? Colors.transparent
                                      : const Color(
                                          0xFFEBC374,
                                        ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.bolt_rounded,
                                  color: n.isRead
                                      ? Colors.white38
                                      : const Color(0xFFEBC374),
                                ),
                                title: Text(
                                  n.title,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Builder(
                                  builder: (context) {
                                    String displayText = n.message;
                                    try {
                                      String cleaned = displayText.trim();
                                      if (cleaned.contains('```')) {
                                        final firstBrace = cleaned.indexOf('{');
                                        final lastBrace = cleaned.lastIndexOf(
                                          '}',
                                        );
                                        if (firstBrace != -1 &&
                                            lastBrace != -1 &&
                                            lastBrace > firstBrace) {
                                          cleaned = cleaned.substring(
                                            firstBrace,
                                            lastBrace + 1,
                                          );
                                        }
                                      }
                                      if (cleaned.startsWith('{')) {
                                        final map = jsonDecode(cleaned);
                                        displayText =
                                            map['todayFocus']?.toString() ??
                                            map['message']?.toString() ??
                                            map['content']?.toString() ??
                                            displayText;
                                      }
                                    } catch (_) {}
                                    return Text(
                                      displayText,
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    );
                                  },
                                ),
                                trailing: Text(
                                  '${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 10,
                                  ),
                                ),
                                onTap: () => ns.markAsRead(n.id),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (index * 100).ms)
                            .slideX(begin: 0.1, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalPicker(BuildContext context, AiCoachController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1528).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Text(
                'HEDEF SEÇ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...Goal.values.map(
                (g) => ListTile(
                  leading: Radio<Goal>(
                    value: g,
                    // ignore: deprecated_member_use
                    groupValue: controller.goal,
                    activeColor: const Color(0xFFEBC374),
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      if (val != null) {
                        controller.setGoal(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(
                    g.label,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    g.subtitle,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.setGoal(g);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonalityPicker(
    BuildContext context,
    AiCoachController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1528).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Text(
                'KOÇ KARAKTERİ SEÇ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...CoachPersonality.values.map(
                (p) => ListTile(
                  leading: Radio<CoachPersonality>(
                    value: p,
                    // ignore: deprecated_member_use
                    groupValue: controller.personality,
                    activeColor: const Color(0xFFEBC374),
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      if (val != null) {
                        controller.setPersonality(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(
                    p.label,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    p.instruction,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.setPersonality(p);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(AiCoachController controller) {
    final disabled =
        controller.isLoading || controller.isCooldownActive || !_hasText;

    final button = GestureDetector(
      onTap: disabled ? null : () => _handleSend(controller),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: disabled
              ? const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFEBC374), Color(0xFFC88934)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFEBC374).withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
        ),
        child: Center(
          child: controller.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    key: ValueKey(disabled),
                    color: disabled
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                    size: 20,
                  ),
                ),
        ),
      ),
    );

    if (!controller.isLoading) return button;

    return button
        .animate(key: ValueKey(controller.isLoading), onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: Colors.white.withValues(alpha: 0.15),
        );
  }
}
