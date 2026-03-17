// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sync.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingSyncAdapter extends TypeAdapter<PendingSync> {
  @override
  final int typeId = 44;

  @override
  PendingSync read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingSync(
      id: fields[0] as String,
      entityType: fields[1] as String,
      action: fields[2] as String,
      payload: fields[3] as String,
      createdAt: fields[4] as DateTime?,
      retryCount: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PendingSync obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityType)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingSyncAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
