// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) {
  return _BookingModel.fromJson(json);
}

/// @nodoc
mixin _$BookingModel {
  String get id => throw _privateConstructorUsedError;
  String get customerId => throw _privateConstructorUsedError;
  String get vendorId => throw _privateConstructorUsedError;
  String get carId => throw _privateConstructorUsedError;
  String get tripType =>
      throw _privateConstructorUsedError; // Local, Outstation, Airport, Self-Drive
  String get pickupLocation => throw _privateConstructorUsedError;
  String? get dropLocation => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  double get totalFare => throw _privateConstructorUsedError;
  double get platformFee => throw _privateConstructorUsedError;
  double get gstAmount => throw _privateConstructorUsedError;
  double get netToVendor => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // pending, confirmed, ongoing, completed, cancelled
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get disputeFlag => throw _privateConstructorUsedError;
  String? get disputeNote => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BookingModelCopyWith<BookingModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookingModelCopyWith<$Res> {
  factory $BookingModelCopyWith(
          BookingModel value, $Res Function(BookingModel) then) =
      _$BookingModelCopyWithImpl<$Res, BookingModel>;
  @useResult
  $Res call(
      {String id,
      String customerId,
      String vendorId,
      String carId,
      String tripType,
      String pickupLocation,
      String? dropLocation,
      DateTime startDate,
      DateTime endDate,
      double totalFare,
      double platformFee,
      double gstAmount,
      double netToVendor,
      String status,
      DateTime createdAt,
      bool disputeFlag,
      String? disputeNote});
}

/// @nodoc
class _$BookingModelCopyWithImpl<$Res, $Val extends BookingModel>
    implements $BookingModelCopyWith<$Res> {
  _$BookingModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? customerId = null,
    Object? vendorId = null,
    Object? carId = null,
    Object? tripType = null,
    Object? pickupLocation = null,
    Object? dropLocation = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? totalFare = null,
    Object? platformFee = null,
    Object? gstAmount = null,
    Object? netToVendor = null,
    Object? status = null,
    Object? createdAt = null,
    Object? disputeFlag = null,
    Object? disputeNote = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      customerId: null == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as String,
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      carId: null == carId
          ? _value.carId
          : carId // ignore: cast_nullable_to_non_nullable
              as String,
      tripType: null == tripType
          ? _value.tripType
          : tripType // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLocation: null == pickupLocation
          ? _value.pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as String,
      dropLocation: freezed == dropLocation
          ? _value.dropLocation
          : dropLocation // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalFare: null == totalFare
          ? _value.totalFare
          : totalFare // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _value.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      gstAmount: null == gstAmount
          ? _value.gstAmount
          : gstAmount // ignore: cast_nullable_to_non_nullable
              as double,
      netToVendor: null == netToVendor
          ? _value.netToVendor
          : netToVendor // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      disputeFlag: null == disputeFlag
          ? _value.disputeFlag
          : disputeFlag // ignore: cast_nullable_to_non_nullable
              as bool,
      disputeNote: freezed == disputeNote
          ? _value.disputeNote
          : disputeNote // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BookingModelImplCopyWith<$Res>
    implements $BookingModelCopyWith<$Res> {
  factory _$$BookingModelImplCopyWith(
          _$BookingModelImpl value, $Res Function(_$BookingModelImpl) then) =
      __$$BookingModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String customerId,
      String vendorId,
      String carId,
      String tripType,
      String pickupLocation,
      String? dropLocation,
      DateTime startDate,
      DateTime endDate,
      double totalFare,
      double platformFee,
      double gstAmount,
      double netToVendor,
      String status,
      DateTime createdAt,
      bool disputeFlag,
      String? disputeNote});
}

/// @nodoc
class __$$BookingModelImplCopyWithImpl<$Res>
    extends _$BookingModelCopyWithImpl<$Res, _$BookingModelImpl>
    implements _$$BookingModelImplCopyWith<$Res> {
  __$$BookingModelImplCopyWithImpl(
      _$BookingModelImpl _value, $Res Function(_$BookingModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? customerId = null,
    Object? vendorId = null,
    Object? carId = null,
    Object? tripType = null,
    Object? pickupLocation = null,
    Object? dropLocation = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? totalFare = null,
    Object? platformFee = null,
    Object? gstAmount = null,
    Object? netToVendor = null,
    Object? status = null,
    Object? createdAt = null,
    Object? disputeFlag = null,
    Object? disputeNote = freezed,
  }) {
    return _then(_$BookingModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      customerId: null == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as String,
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      carId: null == carId
          ? _value.carId
          : carId // ignore: cast_nullable_to_non_nullable
              as String,
      tripType: null == tripType
          ? _value.tripType
          : tripType // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLocation: null == pickupLocation
          ? _value.pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as String,
      dropLocation: freezed == dropLocation
          ? _value.dropLocation
          : dropLocation // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalFare: null == totalFare
          ? _value.totalFare
          : totalFare // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _value.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      gstAmount: null == gstAmount
          ? _value.gstAmount
          : gstAmount // ignore: cast_nullable_to_non_nullable
              as double,
      netToVendor: null == netToVendor
          ? _value.netToVendor
          : netToVendor // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      disputeFlag: null == disputeFlag
          ? _value.disputeFlag
          : disputeFlag // ignore: cast_nullable_to_non_nullable
              as bool,
      disputeNote: freezed == disputeNote
          ? _value.disputeNote
          : disputeNote // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BookingModelImpl implements _BookingModel {
  const _$BookingModelImpl(
      {required this.id,
      required this.customerId,
      required this.vendorId,
      required this.carId,
      required this.tripType,
      required this.pickupLocation,
      this.dropLocation,
      required this.startDate,
      required this.endDate,
      required this.totalFare,
      required this.platformFee,
      required this.gstAmount,
      required this.netToVendor,
      required this.status,
      required this.createdAt,
      this.disputeFlag = false,
      this.disputeNote});

  factory _$BookingModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookingModelImplFromJson(json);

  @override
  final String id;
  @override
  final String customerId;
  @override
  final String vendorId;
  @override
  final String carId;
  @override
  final String tripType;
// Local, Outstation, Airport, Self-Drive
  @override
  final String pickupLocation;
  @override
  final String? dropLocation;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final double totalFare;
  @override
  final double platformFee;
  @override
  final double gstAmount;
  @override
  final double netToVendor;
  @override
  final String status;
// pending, confirmed, ongoing, completed, cancelled
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool disputeFlag;
  @override
  final String? disputeNote;

  @override
  String toString() {
    return 'BookingModel(id: $id, customerId: $customerId, vendorId: $vendorId, carId: $carId, tripType: $tripType, pickupLocation: $pickupLocation, dropLocation: $dropLocation, startDate: $startDate, endDate: $endDate, totalFare: $totalFare, platformFee: $platformFee, gstAmount: $gstAmount, netToVendor: $netToVendor, status: $status, createdAt: $createdAt, disputeFlag: $disputeFlag, disputeNote: $disputeNote)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookingModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.customerId, customerId) ||
                other.customerId == customerId) &&
            (identical(other.vendorId, vendorId) ||
                other.vendorId == vendorId) &&
            (identical(other.carId, carId) || other.carId == carId) &&
            (identical(other.tripType, tripType) ||
                other.tripType == tripType) &&
            (identical(other.pickupLocation, pickupLocation) ||
                other.pickupLocation == pickupLocation) &&
            (identical(other.dropLocation, dropLocation) ||
                other.dropLocation == dropLocation) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.totalFare, totalFare) ||
                other.totalFare == totalFare) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.gstAmount, gstAmount) ||
                other.gstAmount == gstAmount) &&
            (identical(other.netToVendor, netToVendor) ||
                other.netToVendor == netToVendor) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.disputeFlag, disputeFlag) ||
                other.disputeFlag == disputeFlag) &&
            (identical(other.disputeNote, disputeNote) ||
                other.disputeNote == disputeNote));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      customerId,
      vendorId,
      carId,
      tripType,
      pickupLocation,
      dropLocation,
      startDate,
      endDate,
      totalFare,
      platformFee,
      gstAmount,
      netToVendor,
      status,
      createdAt,
      disputeFlag,
      disputeNote);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BookingModelImplCopyWith<_$BookingModelImpl> get copyWith =>
      __$$BookingModelImplCopyWithImpl<_$BookingModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookingModelImplToJson(
      this,
    );
  }
}

abstract class _BookingModel implements BookingModel {
  const factory _BookingModel(
      {required final String id,
      required final String customerId,
      required final String vendorId,
      required final String carId,
      required final String tripType,
      required final String pickupLocation,
      final String? dropLocation,
      required final DateTime startDate,
      required final DateTime endDate,
      required final double totalFare,
      required final double platformFee,
      required final double gstAmount,
      required final double netToVendor,
      required final String status,
      required final DateTime createdAt,
      final bool disputeFlag,
      final String? disputeNote}) = _$BookingModelImpl;

  factory _BookingModel.fromJson(Map<String, dynamic> json) =
      _$BookingModelImpl.fromJson;

  @override
  String get id;
  @override
  String get customerId;
  @override
  String get vendorId;
  @override
  String get carId;
  @override
  String get tripType;
  @override // Local, Outstation, Airport, Self-Drive
  String get pickupLocation;
  @override
  String? get dropLocation;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  double get totalFare;
  @override
  double get platformFee;
  @override
  double get gstAmount;
  @override
  double get netToVendor;
  @override
  String get status;
  @override // pending, confirmed, ongoing, completed, cancelled
  DateTime get createdAt;
  @override
  bool get disputeFlag;
  @override
  String? get disputeNote;
  @override
  @JsonKey(ignore: true)
  _$$BookingModelImplCopyWith<_$BookingModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
