// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McpHttp _$McpHttpFromJson(Map<String, dynamic> json) => McpHttp(
  url: json['url'] as String,
  oAuthTokens: json['oAuthTokens'] == null
      ? null
      : OAuthTokens.fromJson(json['oAuthTokens'] as Map<String, dynamic>),
);

Map<String, dynamic> _$McpHttpToJson(McpHttp instance) => <String, dynamic>{
  'url': instance.url,
  'oAuthTokens': ?instance.oAuthTokens?.toJson(),
};

OAuthTokens _$OAuthTokensFromJson(Map<String, dynamic> json) => OAuthTokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String?,
);

Map<String, dynamic> _$OAuthTokensToJson(OAuthTokens instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': ?instance.refreshToken,
    };
