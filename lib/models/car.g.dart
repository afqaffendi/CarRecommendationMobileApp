// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CarAdapter extends TypeAdapter<Car> {
  @override
  final int typeId = 0;

  @override
  Car read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Car(
      brand: fields[0] as String,
      model: fields[1] as String,
      price: fields[2] as double,
      fuelEconomy: fields[3] as double,
      seats: fields[4] as int,
      bootSpace: fields[5] as int,
      safetyRating: fields[6] as int,
      horsepower: fields[7] as double,
      usageType: fields[8] as String,
      parkingSize: fields[9] as String,
      imageUrl: fields[10] as String?,
      variant: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Car obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.brand)
      ..writeByte(1)
      ..write(obj.model)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.fuelEconomy)
      ..writeByte(4)
      ..write(obj.seats)
      ..writeByte(5)
      ..write(obj.bootSpace)
      ..writeByte(6)
      ..write(obj.safetyRating)
      ..writeByte(7)
      ..write(obj.horsepower)
      ..writeByte(8)
      ..write(obj.usageType)
      ..writeByte(9)
      ..write(obj.parkingSize)
      ..writeByte(10)
      ..write(obj.imageUrl)
      ..writeByte(11)
      ..write(obj.variant);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
