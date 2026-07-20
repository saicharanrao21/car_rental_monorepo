import 'package:freezed_annotation/freezed_annotation.dart';

part 'commission_config_model.freezed.dart';
part 'commission_config_model.g.dart';

@freezed
class CommissionConfigModel with _$CommissionConfigModel {
  const factory CommissionConfigModel({
    required String id,
    required String tripType,
    required String city,
    required String carCategory,
    required double percentage,
    required DateTime effectiveFrom,
  }) = _CommissionConfigModel;

  factory CommissionConfigModel.fromJson(Map<String, dynamic> json) => _$CommissionConfigModelFromJson(json);
}
