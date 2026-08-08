import 'package:freezed_annotation/freezed_annotation.dart';

part 'encryption_models.freezed.dart';
part 'encryption_models.g.dart';

@freezed
class EncryptedEnvelope with _$EncryptedEnvelope {
  const factory EncryptedEnvelope({
    @Default('AES-256-GCM') String algorithm,
    required String nonce,
    required String ciphertext,
  }) = _EncryptedEnvelope;

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) =>
      _$EncryptedEnvelopeFromJson(json);
}

@freezed
class WrappedKeyEnvelope with _$WrappedKeyEnvelope {
  const factory WrappedKeyEnvelope({
    required String ephemeralPublicKey,
    required String nonce,
    required String ciphertext,
  }) = _WrappedKeyEnvelope;

  factory WrappedKeyEnvelope.fromJson(Map<String, dynamic> json) =>
      _$WrappedKeyEnvelopeFromJson(json);
}
