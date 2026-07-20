// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BannerModelImpl _$$BannerModelImplFromJson(Map<String, dynamic> json) =>
    _$BannerModelImpl(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      title: json['title'] as String,
      ctaLink: json['ctaLink'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$BannerModelImplToJson(_$BannerModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'imageUrl': instance.imageUrl,
      'title': instance.title,
      'ctaLink': instance.ctaLink,
      'displayOrder': instance.displayOrder,
      'isActive': instance.isActive,
    };
