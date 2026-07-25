// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'car_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CarModel {
  String get id => throw _privateConstructorUsedError;
  String get vendorId => throw _privateConstructorUsedError;
  String get make => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // Hatchback, Sedan, SUV, Luxury, etc.
  String get fuelType => throw _privateConstructorUsedError;
  int get seating => throw _privateConstructorUsedError;
  bool get isAC => throw _privateConstructorUsedError;
  List<String> get photos => throw _privateConstructorUsedError;
  double get pricePerKm => throw _privateConstructorUsedError;
  double get pricePerDay => throw _privateConstructorUsedError;
  double get pricePerHour => throw _privateConstructorUsedError;
  String get registrationNumber => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  List<String> get availableTripTypes => throw _privateConstructorUsedError;
  List<DateTime> get blockedDates => throw _privateConstructorUsedError;
  double? get distanceKm => throw _privateConstructorUsedError;
  bool get isSponsored => throw _privateConstructorUsedError;
  Map<String, dynamic>? get vendor => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CarModelCopyWith<CarModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CarModelCopyWith<$Res> {
  factory $CarModelCopyWith(CarModel value, $Res Function(CarModel) then) =
      _$CarModelCopyWithImpl<$Res, CarModel>;
  @useResult
  $Res call(
      {String id,
      String vendorId,
      String make,
      String model,
      int year,
      String type,
      String fuelType,
      int seating,
      bool isAC,
      List<String> photos,
      double pricePerKm,
      double pricePerDay,
      double pricePerHour,
      String registrationNumber,
      bool isAvailable,
      double rating,
      List<String> availableTripTypes,
      List<DateTime> blockedDates,
      double? distanceKm,
      bool isSponsored,
      Map<String, dynamic>? vendor});
}

/// @nodoc
class _$CarModelCopyWithImpl<$Res, $Val extends CarModel>
    implements $CarModelCopyWith<$Res> {
  _$CarModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? vendorId = null,
    Object? make = null,
    Object? model = null,
    Object? year = null,
    Object? type = null,
    Object? fuelType = null,
    Object? seating = null,
    Object? isAC = null,
    Object? photos = null,
    Object? pricePerKm = null,
    Object? pricePerDay = null,
    Object? pricePerHour = null,
    Object? registrationNumber = null,
    Object? isAvailable = null,
    Object? rating = null,
    Object? availableTripTypes = null,
    Object? blockedDates = null,
    Object? distanceKm = freezed,
    Object? isSponsored = null,
    Object? vendor = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      make: null == make
          ? _value.make
          : make // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      fuelType: null == fuelType
          ? _value.fuelType
          : fuelType // ignore: cast_nullable_to_non_nullable
              as String,
      seating: null == seating
          ? _value.seating
          : seating // ignore: cast_nullable_to_non_nullable
              as int,
      isAC: null == isAC
          ? _value.isAC
          : isAC // ignore: cast_nullable_to_non_nullable
              as bool,
      photos: null == photos
          ? _value.photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>,
      pricePerKm: null == pricePerKm
          ? _value.pricePerKm
          : pricePerKm // ignore: cast_nullable_to_non_nullable
              as double,
      pricePerDay: null == pricePerDay
          ? _value.pricePerDay
          : pricePerDay // ignore: cast_nullable_to_non_nullable
              as double,
      pricePerHour: null == pricePerHour
          ? _value.pricePerHour
          : pricePerHour // ignore: cast_nullable_to_non_nullable
              as double,
      registrationNumber: null == registrationNumber
          ? _value.registrationNumber
          : registrationNumber // ignore: cast_nullable_to_non_nullable
              as String,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      availableTripTypes: null == availableTripTypes
          ? _value.availableTripTypes
          : availableTripTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      blockedDates: null == blockedDates
          ? _value.blockedDates
          : blockedDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
      distanceKm: freezed == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double?,
      isSponsored: null == isSponsored
          ? _value.isSponsored
          : isSponsored // ignore: cast_nullable_to_non_nullable
              as bool,
      vendor: freezed == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CarModelImplCopyWith<$Res>
    implements $CarModelCopyWith<$Res> {
  factory _$$CarModelImplCopyWith(
          _$CarModelImpl value, $Res Function(_$CarModelImpl) then) =
      __$$CarModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String vendorId,
      String make,
      String model,
      int year,
      String type,
      String fuelType,
      int seating,
      bool isAC,
      List<String> photos,
      double pricePerKm,
      double pricePerDay,
      double pricePerHour,
      String registrationNumber,
      bool isAvailable,
      double rating,
      List<String> availableTripTypes,
      List<DateTime> blockedDates,
      double? distanceKm,
      bool isSponsored,
      Map<String, dynamic>? vendor});
}

/// @nodoc
class __$$CarModelImplCopyWithImpl<$Res>
    extends _$CarModelCopyWithImpl<$Res, _$CarModelImpl>
    implements _$$CarModelImplCopyWith<$Res> {
  __$$CarModelImplCopyWithImpl(
      _$CarModelImpl _value, $Res Function(_$CarModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? vendorId = null,
    Object? make = null,
    Object? model = null,
    Object? year = null,
    Object? type = null,
    Object? fuelType = null,
    Object? seating = null,
    Object? isAC = null,
    Object? photos = null,
    Object? pricePerKm = null,
    Object? pricePerDay = null,
    Object? pricePerHour = null,
    Object? registrationNumber = null,
    Object? isAvailable = null,
    Object? rating = null,
    Object? availableTripTypes = null,
    Object? blockedDates = null,
    Object? distanceKm = freezed,
    Object? isSponsored = null,
    Object? vendor = freezed,
  }) {
    return _then(_$CarModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      make: null == make
          ? _value.make
          : make // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      fuelType: null == fuelType
          ? _value.fuelType
          : fuelType // ignore: cast_nullable_to_non_nullable
              as String,
      seating: null == seating
          ? _value.seating
          : seating // ignore: cast_nullable_to_non_nullable
              as int,
      isAC: null == isAC
          ? _value.isAC
          : isAC // ignore: cast_nullable_to_non_nullable
              as bool,
      photos: null == photos
          ? _value._photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>,
      pricePerKm: null == pricePerKm
          ? _value.pricePerKm
          : pricePerKm // ignore: cast_nullable_to_non_nullable
              as double,
      pricePerDay: null == pricePerDay
          ? _value.pricePerDay
          : pricePerDay // ignore: cast_nullable_to_non_nullable
              as double,
      pricePerHour: null == pricePerHour
          ? _value.pricePerHour
          : pricePerHour // ignore: cast_nullable_to_non_nullable
              as double,
      registrationNumber: null == registrationNumber
          ? _value.registrationNumber
          : registrationNumber // ignore: cast_nullable_to_non_nullable
              as String,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      availableTripTypes: null == availableTripTypes
          ? _value._availableTripTypes
          : availableTripTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      blockedDates: null == blockedDates
          ? _value._blockedDates
          : blockedDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
      distanceKm: freezed == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double?,
      isSponsored: null == isSponsored
          ? _value.isSponsored
          : isSponsored // ignore: cast_nullable_to_non_nullable
              as bool,
      vendor: freezed == vendor
          ? _value._vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc

class _$CarModelImpl implements _CarModel {
  const _$CarModelImpl(
      {required this.id,
      required this.vendorId,
      required this.make,
      required this.model,
      required this.year,
      required this.type,
      required this.fuelType,
      required this.seating,
      required this.isAC,
      required final List<String> photos,
      required this.pricePerKm,
      required this.pricePerDay,
      required this.pricePerHour,
      this.registrationNumber = '',
      this.isAvailable = true,
      this.rating = 0.0,
      final List<String> availableTripTypes = const [
        'Local',
        'Outstation',
        'Airport Transfer',
        'Self-Drive'
      ],
      final List<DateTime> blockedDates = const [],
      this.distanceKm,
      this.isSponsored = false,
      final Map<String, dynamic>? vendor})
      : _photos = photos,
        _availableTripTypes = availableTripTypes,
        _blockedDates = blockedDates,
        _vendor = vendor;

  @override
  final String id;
  @override
  final String vendorId;
  @override
  final String make;
  @override
  final String model;
  @override
  final int year;
  @override
  final String type;
// Hatchback, Sedan, SUV, Luxury, etc.
  @override
  final String fuelType;
  @override
  final int seating;
  @override
  final bool isAC;
  final List<String> _photos;
  @override
  List<String> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  @override
  final double pricePerKm;
  @override
  final double pricePerDay;
  @override
  final double pricePerHour;
  @override
  @JsonKey()
  final String registrationNumber;
  @override
  @JsonKey()
  final bool isAvailable;
  @override
  @JsonKey()
  final double rating;
  final List<String> _availableTripTypes;
  @override
  @JsonKey()
  List<String> get availableTripTypes {
    if (_availableTripTypes is EqualUnmodifiableListView)
      return _availableTripTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableTripTypes);
  }

  final List<DateTime> _blockedDates;
  @override
  @JsonKey()
  List<DateTime> get blockedDates {
    if (_blockedDates is EqualUnmodifiableListView) return _blockedDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedDates);
  }

  @override
  final double? distanceKm;
  @override
  @JsonKey()
  final bool isSponsored;
  final Map<String, dynamic>? _vendor;
  @override
  Map<String, dynamic>? get vendor {
    final value = _vendor;
    if (value == null) return null;
    if (_vendor is EqualUnmodifiableMapView) return _vendor;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'CarModel(id: $id, vendorId: $vendorId, make: $make, model: $model, year: $year, type: $type, fuelType: $fuelType, seating: $seating, isAC: $isAC, photos: $photos, pricePerKm: $pricePerKm, pricePerDay: $pricePerDay, pricePerHour: $pricePerHour, registrationNumber: $registrationNumber, isAvailable: $isAvailable, rating: $rating, availableTripTypes: $availableTripTypes, blockedDates: $blockedDates, distanceKm: $distanceKm, isSponsored: $isSponsored, vendor: $vendor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CarModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.vendorId, vendorId) ||
                other.vendorId == vendorId) &&
            (identical(other.make, make) || other.make == make) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.fuelType, fuelType) ||
                other.fuelType == fuelType) &&
            (identical(other.seating, seating) || other.seating == seating) &&
            (identical(other.isAC, isAC) || other.isAC == isAC) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            (identical(other.pricePerKm, pricePerKm) ||
                other.pricePerKm == pricePerKm) &&
            (identical(other.pricePerDay, pricePerDay) ||
                other.pricePerDay == pricePerDay) &&
            (identical(other.pricePerHour, pricePerHour) ||
                other.pricePerHour == pricePerHour) &&
            (identical(other.registrationNumber, registrationNumber) ||
                other.registrationNumber == registrationNumber) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            const DeepCollectionEquality()
                .equals(other._availableTripTypes, _availableTripTypes) &&
            const DeepCollectionEquality()
                .equals(other._blockedDates, _blockedDates) &&
            (identical(other.distanceKm, distanceKm) ||
                other.distanceKm == distanceKm) &&
            (identical(other.isSponsored, isSponsored) ||
                other.isSponsored == isSponsored) &&
            const DeepCollectionEquality().equals(other._vendor, _vendor));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        vendorId,
        make,
        model,
        year,
        type,
        fuelType,
        seating,
        isAC,
        const DeepCollectionEquality().hash(_photos),
        pricePerKm,
        pricePerDay,
        pricePerHour,
        registrationNumber,
        isAvailable,
        rating,
        const DeepCollectionEquality().hash(_availableTripTypes),
        const DeepCollectionEquality().hash(_blockedDates),
        distanceKm,
        isSponsored,
        const DeepCollectionEquality().hash(_vendor)
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CarModelImplCopyWith<_$CarModelImpl> get copyWith =>
      __$$CarModelImplCopyWithImpl<_$CarModelImpl>(this, _$identity);
}

abstract class _CarModel implements CarModel {
  const factory _CarModel(
      {required final String id,
      required final String vendorId,
      required final String make,
      required final String model,
      required final int year,
      required final String type,
      required final String fuelType,
      required final int seating,
      required final bool isAC,
      required final List<String> photos,
      required final double pricePerKm,
      required final double pricePerDay,
      required final double pricePerHour,
      final String registrationNumber,
      final bool isAvailable,
      final double rating,
      final List<String> availableTripTypes,
      final List<DateTime> blockedDates,
      final double? distanceKm,
      final bool isSponsored,
      final Map<String, dynamic>? vendor}) = _$CarModelImpl;

  @override
  String get id;
  @override
  String get vendorId;
  @override
  String get make;
  @override
  String get model;
  @override
  int get year;
  @override
  String get type;
  @override // Hatchback, Sedan, SUV, Luxury, etc.
  String get fuelType;
  @override
  int get seating;
  @override
  bool get isAC;
  @override
  List<String> get photos;
  @override
  double get pricePerKm;
  @override
  double get pricePerDay;
  @override
  double get pricePerHour;
  @override
  String get registrationNumber;
  @override
  bool get isAvailable;
  @override
  double get rating;
  @override
  List<String> get availableTripTypes;
  @override
  List<DateTime> get blockedDates;
  @override
  double? get distanceKm;
  @override
  bool get isSponsored;
  @override
  Map<String, dynamic>? get vendor;
  @override
  @JsonKey(ignore: true)
  _$$CarModelImplCopyWith<_$CarModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
