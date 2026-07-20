// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'earnings_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EarningsModel _$EarningsModelFromJson(Map<String, dynamic> json) {
  return _EarningsModel.fromJson(json);
}

/// @nodoc
mixin _$EarningsModel {
  String get vendorId => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  double get grossAmount => throw _privateConstructorUsedError;
  double get platformFee => throw _privateConstructorUsedError;
  double get gstAmount => throw _privateConstructorUsedError;
  double get netAmount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EarningsModelCopyWith<EarningsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EarningsModelCopyWith<$Res> {
  factory $EarningsModelCopyWith(
          EarningsModel value, $Res Function(EarningsModel) then) =
      _$EarningsModelCopyWithImpl<$Res, EarningsModel>;
  @useResult
  $Res call(
      {String vendorId,
      DateTime date,
      double grossAmount,
      double platformFee,
      double gstAmount,
      double netAmount});
}

/// @nodoc
class _$EarningsModelCopyWithImpl<$Res, $Val extends EarningsModel>
    implements $EarningsModelCopyWith<$Res> {
  _$EarningsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vendorId = null,
    Object? date = null,
    Object? grossAmount = null,
    Object? platformFee = null,
    Object? gstAmount = null,
    Object? netAmount = null,
  }) {
    return _then(_value.copyWith(
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      grossAmount: null == grossAmount
          ? _value.grossAmount
          : grossAmount // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _value.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      gstAmount: null == gstAmount
          ? _value.gstAmount
          : gstAmount // ignore: cast_nullable_to_non_nullable
              as double,
      netAmount: null == netAmount
          ? _value.netAmount
          : netAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EarningsModelImplCopyWith<$Res>
    implements $EarningsModelCopyWith<$Res> {
  factory _$$EarningsModelImplCopyWith(
          _$EarningsModelImpl value, $Res Function(_$EarningsModelImpl) then) =
      __$$EarningsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String vendorId,
      DateTime date,
      double grossAmount,
      double platformFee,
      double gstAmount,
      double netAmount});
}

/// @nodoc
class __$$EarningsModelImplCopyWithImpl<$Res>
    extends _$EarningsModelCopyWithImpl<$Res, _$EarningsModelImpl>
    implements _$$EarningsModelImplCopyWith<$Res> {
  __$$EarningsModelImplCopyWithImpl(
      _$EarningsModelImpl _value, $Res Function(_$EarningsModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vendorId = null,
    Object? date = null,
    Object? grossAmount = null,
    Object? platformFee = null,
    Object? gstAmount = null,
    Object? netAmount = null,
  }) {
    return _then(_$EarningsModelImpl(
      vendorId: null == vendorId
          ? _value.vendorId
          : vendorId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      grossAmount: null == grossAmount
          ? _value.grossAmount
          : grossAmount // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _value.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      gstAmount: null == gstAmount
          ? _value.gstAmount
          : gstAmount // ignore: cast_nullable_to_non_nullable
              as double,
      netAmount: null == netAmount
          ? _value.netAmount
          : netAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EarningsModelImpl implements _EarningsModel {
  const _$EarningsModelImpl(
      {required this.vendorId,
      required this.date,
      required this.grossAmount,
      required this.platformFee,
      required this.gstAmount,
      required this.netAmount});

  factory _$EarningsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EarningsModelImplFromJson(json);

  @override
  final String vendorId;
  @override
  final DateTime date;
  @override
  final double grossAmount;
  @override
  final double platformFee;
  @override
  final double gstAmount;
  @override
  final double netAmount;

  @override
  String toString() {
    return 'EarningsModel(vendorId: $vendorId, date: $date, grossAmount: $grossAmount, platformFee: $platformFee, gstAmount: $gstAmount, netAmount: $netAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EarningsModelImpl &&
            (identical(other.vendorId, vendorId) ||
                other.vendorId == vendorId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.grossAmount, grossAmount) ||
                other.grossAmount == grossAmount) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.gstAmount, gstAmount) ||
                other.gstAmount == gstAmount) &&
            (identical(other.netAmount, netAmount) ||
                other.netAmount == netAmount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, vendorId, date, grossAmount,
      platformFee, gstAmount, netAmount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EarningsModelImplCopyWith<_$EarningsModelImpl> get copyWith =>
      __$$EarningsModelImplCopyWithImpl<_$EarningsModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EarningsModelImplToJson(
      this,
    );
  }
}

abstract class _EarningsModel implements EarningsModel {
  const factory _EarningsModel(
      {required final String vendorId,
      required final DateTime date,
      required final double grossAmount,
      required final double platformFee,
      required final double gstAmount,
      required final double netAmount}) = _$EarningsModelImpl;

  factory _EarningsModel.fromJson(Map<String, dynamic> json) =
      _$EarningsModelImpl.fromJson;

  @override
  String get vendorId;
  @override
  DateTime get date;
  @override
  double get grossAmount;
  @override
  double get platformFee;
  @override
  double get gstAmount;
  @override
  double get netAmount;
  @override
  @JsonKey(ignore: true)
  _$$EarningsModelImplCopyWith<_$EarningsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
