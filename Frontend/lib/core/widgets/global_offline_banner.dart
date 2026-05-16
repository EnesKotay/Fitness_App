import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../features/sync/services/offline_sync_service.dart';

class GlobalOfflineBanner extends StatefulWidget {
  const GlobalOfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalOfflineBanner> createState() => _GlobalOfflineBannerState();
}

class _GlobalOfflineBannerState extends State<GlobalOfflineBanner> {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _sync = OfflineSyncService();
  late final Listenable _syncAnims;

  @override
  void initState() {
    super.initState();
    unawaited(_sync.init());
    _syncAnims = Listenable.merge([_sync.pendingCount, _sync.isSyncing]);
    _refreshConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateFromResults,
    );
  }

  Future<void> _refreshConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    _updateFromResults(results);
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final offline = results.every(
      (result) => result == ConnectivityResult.none,
    );
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _offline ? _offlineBanner() : _syncBanner(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _offlineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF7F1D1D),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white70),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'İnternet bağlantısı yok. Bazı özellikler sınırlı çalışabilir.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncBanner() {
    return AnimatedBuilder(
      animation: _syncAnims,
      builder: (context, _) {
        final count = _sync.pendingCount.value;
        final syncing = _sync.isSyncing.value;
        if (count == 0 && !syncing) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFF173B2F),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  syncing ? Icons.sync_rounded : Icons.cloud_queue_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    syncing
                        ? 'Veriler senkronize ediliyor...'
                        : '$count işlem senkron bekliyor.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
