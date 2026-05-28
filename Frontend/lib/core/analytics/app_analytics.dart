import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/storage_helper.dart';

class AppAnalyticsEvent {
  final String name;
  final DateTime createdAt;
  final Map<String, Object?> properties;

  const AppAnalyticsEvent({
    required this.name,
    required this.createdAt,
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'properties': properties,
  };

  factory AppAnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AppAnalyticsEvent(
      name: json['name']?.toString() ?? 'unknown',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      properties:
          (json['properties'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          ) ??
          const {},
    );
  }
}

class AppAnalytics {
  AppAnalytics._();

  static const _maxEvents = 240;
  static const _baseKey = 'app_analytics_events_v1';

  static String get _key => '${StorageHelper.getUserStorageSuffix()}_$_baseKey';

  static Future<void> track(
    String name, {
    Map<String, Object?> properties = const {},
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const <String>[];
      final next = [
        ...raw.take(_maxEvents - 1),
        jsonEncode(
          AppAnalyticsEvent(
            name: name,
            createdAt: DateTime.now(),
            properties: properties,
          ).toJson(),
        ),
      ];
      await prefs.setStringList(_key, next);
      debugPrint('Analytics: $name ${properties.isEmpty ? '' : properties}');
    } catch (e) {
      debugPrint('AppAnalytics.track error: $e');
    }
  }

  static Future<List<AppAnalyticsEvent>> recentEvents({int limit = 80}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const <String>[];
      return raw.reversed
          .take(limit)
          .map((item) => AppAnalyticsEvent.fromJson(jsonDecode(item)))
          .toList(growable: false);
    } catch (_) {
      return const <AppAnalyticsEvent>[];
    }
  }

  static Future<int> count(String name, {Duration? within}) async {
    final events = await recentEvents(limit: _maxEvents);
    final threshold = within == null ? null : DateTime.now().subtract(within);
    return events.where((event) {
      if (event.name != name) return false;
      if (threshold != null && event.createdAt.isBefore(threshold)) {
        return false;
      }
      return true;
    }).length;
  }
}
