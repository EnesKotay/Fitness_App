// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GenderAdapter extends TypeAdapter<Gender> {
  @override
  final int typeId = 2;

  @override
  Gender read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Gender.male;
      case 1:
        return Gender.female;
      default:
        return Gender.male;
    }
  }

  @override
  void write(BinaryWriter writer, Gender obj) {
    switch (obj) {
      case Gender.male:
        writer.writeByte(0);
        break;
      case Gender.female:
        writer.writeByte(1);
        break;
    }
  }
}

class ActivityLevelAdapter extends TypeAdapter<ActivityLevel> {
  @override
  final int typeId = 3;

  @override
  ActivityLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActivityLevel.sedentary;
      case 1:
        return ActivityLevel.lightlyActive;
      case 2:
        return ActivityLevel.moderatelyActive;
      case 3:
        return ActivityLevel.veryActive;
      case 4:
        return ActivityLevel.extraActive;
      default:
        return ActivityLevel.sedentary;
    }
  }

  @override
  void write(BinaryWriter writer, ActivityLevel obj) {
    switch (obj) {
      case ActivityLevel.sedentary:
        writer.writeByte(0);
        break;
      case ActivityLevel.lightlyActive:
        writer.writeByte(1);
        break;
      case ActivityLevel.moderatelyActive:
        writer.writeByte(2);
        break;
      case ActivityLevel.veryActive:
        writer.writeByte(3);
        break;
      case ActivityLevel.extraActive:
        writer.writeByte(4);
        break;
    }
  }
}

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 4;

  @override
  Goal read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Goal.loseWeight;
      case 1:
        return Goal.maintainWeight;
      case 2:
        return Goal.gainWeight;
      default:
        return Goal.loseWeight;
    }
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    switch (obj) {
      case Goal.loseWeight:
        writer.writeByte(0);
        break;
      case Goal.maintainWeight:
        writer.writeByte(1);
        break;
      case Goal.gainWeight:
        writer.writeByte(2);
        break;
    }
  }
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 5;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      age: fields[1] as int,
      weight: fields[2] as double,
      height: fields[3] as double,
      gender: fields[4] as Gender,
      activityLevel: fields[5] as ActivityLevel,
      goal: fields[6] as Goal,
      customKcalTarget: fields[7] as double?,
      targetWeight: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.height)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.activityLevel)
      ..writeByte(6)
      ..write(obj.goal)
      ..writeByte(7)
      ..write(obj.customKcalTarget)
      ..writeByte(8)
      ..write(obj.targetWeight);
  }
}
