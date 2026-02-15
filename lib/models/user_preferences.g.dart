// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserPreferencesAdapter extends TypeAdapter<UserPreferences> {
  @override
  final int typeId = 1;

  @override
  UserPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPreferences(
      budget: fields[0] as double,
      usageType: fields[1] as String,
      parkingSpace: fields[2] as String,
      priceWeight: fields[3] as double,
      fuelEconomyWeight: fields[4] as double,
      safetyWeight: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, UserPreferences obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.budget)
      ..writeByte(1)
      ..write(obj.usageType)
      ..writeByte(2)
      ..write(obj.parkingSpace)
      ..writeByte(3)
      ..write(obj.priceWeight)
      ..writeByte(4)
      ..write(obj.fuelEconomyWeight)
      ..writeByte(5)
      ..write(obj.safetyWeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
