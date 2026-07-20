// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vendor_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VendorModel _$VendorModelFromJson(Map<String, dynamic> json) {
  return _VendorModel.fromJson(json);
}

/// @nodoc
mixin _$VendorModel {
  String get id => throw _privateConstructorUsedError;
  String get businessName => throw _privateConstructorUsedError;
  String get ownerName => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get businessType => throw _privateConstructorUsedError;
  String? get gstNumber => throw _privateConstructorUsedError;
  String? get panNumber => throw _privateConstructorUsedError;
  String? get bankDetails => throw _privateConstructorUsedError;
  String get verificationStatus =>
      throw _privateConstructorUsedError; // pending, verified, rejected, suspended
  double get rating => throw _privateConstructorUsedError;
  int get totalTrips => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VendorModelCopyWith<VendorModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VendorModelCopyWith<$Res> {
  factory $VendorModelCopyWith(
          VendorModel value, $Res Function(VendorModel) then) =
      _$VendorModelCopyWithImpl<$Res, VendorModel>;
  @useResult
  $Res call(
      {String id,
      String businessName,
      String ownerName,
      String city,
      String phone,
      String? email,
      String? businessType,
      String? gstNumber,
      String? panNumber,
      String? bankDetails,
      String verificationStatus,
      double rating,
      int totalTrips});
}

/// @nodoc
class _$VendorModelCopyWithImpl<$Res, $Val extends VendorModel>
    implements $VendorModelCopyWith<$Res> {
  _$VendorModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessName = null,
    Object? ownerName = null,
    Object? city = null,
    Object? phone = null,
    Object? email = freezed,
    Object? businessType = freezed,
    Object? gstNumber = freezed,
    Object? panNumber = freezed,
    Object? bankDetails = freezed,
    Object? verificationStatus = null,
    Object? rating = null,
    Object? totalTrips = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      businessName: null == businessName
          ? _value.businessName
          : businessName // ignore: cast_nullable_to_non_nullable
              as String,
      ownerName: null == ownerName
          ? _value.ownerName
          : ownerName // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      businessType: freezed == businessType
          ? _value.businessType
          : businessType // ignore: cast_nullable_to_non_nullable
              as String?,
      gstNumber: freezed == gstNumber
          ? _value.gstNumber
          : gstNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      panNumber: freezed == panNumber
          ? _value.panNumber
          : panNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      bankDetails: freezed == bankDetails
          ? _value.bankDetails
          : bankDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      verificationStatus: null == verificationStatus
          ? _value.verificationStatus
          : verificationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalTrips: null == totalTrips
          ? _value.totalTrips
          : totalTrips // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VendorModelImplCopyWith<$Res>
    implements $VendorModelCopyWith<$Res> {
  factory _$$VendorModelImplCopyWith(
          _$VendorModelImpl value, $Res Function(_$VendorModelImpl) then) =
      __$$VendorModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String businessName,
      String ownerName,
      String city,
      String phone,
      String? email,
      String? businessType,
      String? gstNumber,
      String? panNumber,
      String? bankDetails,
      String verificationStatus,
      double rating,
      int totalTrips});
}

/// @nodoc
class __$$VendorModelImplCopyWithImpl<$Res>
    extends _$VendorModelCopyWithImpl<$Res, _$VendorModelImpl>
    implements _$$VendorModelImplCopyWith<$Res> {
  __$$VendorModelImplCopyWithImpl(
      _$VendorModelImpl _value, $Res Function(_$VendorModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessName = null,
    Object? ownerName = null,
    Object? city = null,
    Object? phone = null,
    Object? email = freezed,
    Object? businessType = freezed,
    Object? gstNumber = freezed,
    Object? panNumber = freezed,
    Object? bankDetails = freezed,
    Object? verificationStatus = null,
    Object? rating = null,
    Object? totalTrips = null,
  }) {
    return _then(_$VendorModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      businessName: null == businessName
          ? _value.businessName
          : businessName // ignore: cast_nullable_to_non_nullable
              as String,
      ownerName: null == ownerName
          ? _value.ownerName
          : ownerName // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      businessType: freezed == businessType
          ? _value.businessType
          : businessType // ignore: cast_nullable_to_non_nullable
              as String?,
      gstNumber: freezed == gstNumber
          ? _value.gstNumber
          : gstNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      panNumber: freezed == panNumber
          ? _value.panNumber
          : panNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      bankDetails: freezed == bankDetails
          ? _value.bankDetails
          : bankDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      verificationStatus: null == verificationStatus
          ? _value.verificationStatus
          : verificationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalTrips: null == totalTrips
          ? _value.totalTrips
          : totalTrips // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VendorModelImpl implements _VendorModel {
  const _$VendorModelImpl(
      {required this.id,
      required this.businessName,
      required this.ownerName,
      required this.city,
      this.phone = '',
      this.email,
      this.businessType,
      this.gstNumber,
      this.panNumber,
      this.bankDetails,
      required this.verificationStatus,
      this.rating = 0.0,
      this.totalTrips = 0});

  factory _$VendorModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VendorModelImplFromJson(json);

  @override
  final String id;
  @override
  final String businessName;
  @override
  final String ownerName;
  @override
  final String city;
  @override
  @JsonKey()
  final String phone;
  @override
  final String? email;
  @override
  final String? businessType;
  @override
  final String? gstNumber;
  @override
  final String? panNumber;
  @override
  final String? bankDetails;
  @override
  final String verificationStatus;
// pending, verified, rejected, suspended
  @override
  @JsonKey()
  final double rating;
  @override
  @JsonKey()
  final int totalTrips;

  @override
  String toString() {
    return 'VendorModel(id: $id, businessName: $businessName, ownerName: $ownerName, city: $city, phone: $phone, email: $email, businessType: $businessType, gstNumber: $gstNumber, panNumber: $panNumber, bankDetails: $bankDetails, verificationStatus: $verificationStatus, rating: $rating, totalTrips: $totalTrips)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VendorModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessName, businessName) ||
                other.businessName == businessName) &&
            (identical(other.ownerName, ownerName) ||
                other.ownerName == ownerName) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.businessType, businessType) ||
                other.businessType == businessType) &&
            (identical(other.gstNumber, gstNumber) ||
                other.gstNumber == gstNumber) &&
            (identical(other.panNumber, panNumber) ||
                other.panNumber == panNumber) &&
            (identical(other.bankDetails, bankDetails) ||
                other.bankDetails == bankDetails) &&
            (identical(other.verificationStatus, verificationStatus) ||
                other.verificationStatus == verificationStatus) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalTrips, totalTrips) ||
                other.totalTrips == totalTrips));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      businessName,
      ownerName,
      city,
      phone,
      email,
      businessType,
      gstNumber,
      panNumber,
      bankDetails,
      verificationStatus,
      rating,
      totalTrips);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VendorModelImplCopyWith<_$VendorModelImpl> get copyWith =>
      __$$VendorModelImplCopyWithImpl<_$VendorModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VendorModelImplToJson(
      this,
    );
  }
}

abstract class _VendorModel implements VendorModel {
  const factory _VendorModel(
      {required final String id,
      required final String businessName,
      required final String ownerName,
      required final String city,
      final String phone,
      final String? email,
      final String? businessType,
      final String? gstNumber,
      final String? panNumber,
      final String? bankDetails,
      required final String verificationStatus,
      final double rating,
      final int totalTrips}) = _$VendorModelImpl;

  factory _VendorModel.fromJson(Map<String, dynamic> json) =
      _$VendorModelImpl.fromJson;

  @override
  String get id;
  @override
  String get businessName;
  @override
  String get ownerName;
  @override
  String get city;
  @override
  String get phone;
  @override
  String? get email;
  @override
  String? get businessType;
  @override
  String? get gstNumber;
  @override
  String? get panNumber;
  @override
  String? get bankDetails;
  @override
  String get verificationStatus;
  @override // pending, verified, rejected, suspended
  double get rating;
  @override
  int get totalTrips;
  @override
  @JsonKey(ignore: true)
  _$$VendorModelImplCopyWith<_$VendorModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
