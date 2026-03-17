import 'package:hive/hive.dart';

part 'pending_sync.g.dart';

@HiveType(typeId: 44) // Benzersiz bir ID kullanıldı
class PendingSync extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String entityType; // Örn: 'workout', 'weight', 'meal'

  @HiveField(2)
  final String action; // Örn: 'create', 'update', 'delete'

  @HiveField(3)
  final String payload; // JSON formati

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  int retryCount;

  PendingSync({
    required this.id,
    required this.entityType,
    required this.action,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() {
    return 'PendingSync(id: $id, type: $entityType, action: $action, retries: $retryCount)';
  }
}
