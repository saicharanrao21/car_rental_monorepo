// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commission_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CommissionConfigModel _$CommissionConfigModelFromJson(
    Map<String, dynamic> json) {
  return _CommissionConfigModel.fromJson(json);
}

/// @nodoc
mixin _$CommissionConfigModel {
  String get id => throw _privateConstructorUsedError;
  String get tripType => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get carCategory => throw _privateConstructorUsedError;
  double get percentage => throw _privateConstructorUsedError;
  DateTime get effectiveFrom => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CommissionConfigModelCopyWith<CommissionConfigModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommissionConfigModelCopyWith<$Res> {
  factory $CommissionConfigModelCopyWith(CommissionConfigModel value,
          $Res Function(CommissionConfigModel) then) =
      _$CommissionConfigModelCopyWithImpl<$Res, CommissionConfigModel>;
  @useResult
  $Res call(
      {String id,
      String tripType,
      String city,
      String carCategory,
      double percentage,
      DateTime effectiveFrom});
}

/// @nodoc
class _$CommissionConfigModelCopyWithImpl<$Res,
        $Val extends CommissionConfigModel>
    implements $CommissionConfigModelCopyWith<$Res> {
  _$CommissionConfigModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripType = null,
    Object? city = null,
    Object? carCategory = null,
    Object? percentage = null,
    Object? effectiveFrom = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tripType: null == tripType
          ? _value.tripType
          : tripType // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      carCategory: null == carCategory
          ? _value.carCategory
          : carCategory // ignore: cast_nullable_to_non_nullable
              as String,
      percentage: null == percentage
          ? _value.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
      effectiveFrom: null == effectiveFrom
          ? _value.effectiveFrom
          : effectiveFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommissionConfigModelImplCopyWith<$Res>
    implements $CommissionConfigModelCopyWith<$Res> {
  factory _$$CommissionConfigModelImplCopyWith(
          _$CommissionConfigModelImpl value,
          $Res Function(_$CommissionConfigModelImpl) then) =
      __$$CommissionConfigModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tripType,
      String city,
      String carCategory,
      double percentage,
      DateTime effectiveFrom});
}

/// @nodoc
class __$$CommissionConfigModelImplCopyWithImpl<$Res>
    extends _$CommissionConfigModelCopyWithImpl<$Res,
        _$CommissionConfigModelImpl>
    implements _$$CommissionConfigModelImplCopyWith<$Res> {
  __$$CommissionConfigModelImplCopyWithImpl(_$CommissionConfigModelImpl _value,
      $Res Function(_$CommissionConfigModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tripType = null,
    Object? city = null,
    Object? carCategory = null,
    Object? percentage = null,
    Object? effectiveFrom = null,
  }) {
    return _then(_$CommissionConfigModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tripType: null == tripType
          ? _value.tripType
          : tripType // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      carCategory: null == carCategory
          ? _value.carCategory
          : carCategory // ignore: cast_nullable_to_non_nullable
              as String,
      percentage: null == percentage
          ? _value.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
      effectiveFrom: null == effectiveFrom
          ? _value.effectiveFrom
          : effectiveFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommissionConfigModelImpl implements _CommissionConfigModel {
  const _$CommissionConfigModelImpl(
      {required this.id,
      required this.tripType,
      required this.city,
      required this.carCategory,
      required this.percentage,
      required this.effectiveFrom});

  factory _$CommissionConfigModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommissionConfigModelImplFromJson(json);

  @override
  final String id;
  @override
  final String tripType;
  @override
  final String city;
  @override
  final String carCategory;
  @override
  final double percentage;
  @override
  final DateTime effectiveFrom;

  @override
  String toString() {
    return 'CommissionConfigModel(id: $id, tripType: $tripType, city: $city, carCategory: $carCategory, percentage: $percentage, effectiveFrom: $effectiveFrom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommissionConfigModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tripType, tripType) ||
                other.tripType == tripType) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.carCategory, carCategory) ||
                other.carCategory == carCategory) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            (identical(other.effectiveFrom, effectiveFrom) ||
                other.effectiveFrom == effectiveFrom));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, tripType, city, carCategory, percentage, effectiveFrom);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CommissionConfigModelImplCopyWith<_$CommissionConfigModelImpl>
      get copyWith => __$$CommissionConfigModelImplCopyWithImpl<
          _$CommissionConfigModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommissionConfigModelImplToJson(
      this,
    );
  }
}

abstract class _CommissionConfigModel implements CommissionConfigModel {
  const factory _CommissionConfigModel(
      {required final String id,
      required final String tripType,
      required final String city,
      required final String carCategory,
      required final double percentage,
      required final DateTime effectiveFrom}) = _$CommissionConfigModelImpl;

  factory _CommissionConfigModel.fromJson(Map<String, dynamic> json) =
      _$CommissionConfigModelImpl.fromJson;

  @override
  String get id;
  @override
  String get tripType;
  @override
  String get city;
  @override
  String get carCategory;
  @override
  double get percentage;
  @override
  DateTime get effectiveFrom;
  @override
  @JsonKey(ignore: true)
  _$$CommissionConfigModelImplCopyWith<_$CommissionConfigModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
