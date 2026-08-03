class EncryptedEnvelope {
  const EncryptedEnvelope({required this.nonce, required this.ciphertext});
  final String nonce;
  final String ciphertext;
  Map<String, dynamic> toJson() => {'algorithm': 'AES-256-GCM', 'nonce': nonce, 'ciphertext': ciphertext};
  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) => EncryptedEnvelope(nonce: json['nonce'] as String, ciphertext: json['ciphertext'] as String);
}

class WrappedKeyEnvelope {
  const WrappedKeyEnvelope({required this.ephemeralPublicKey, required this.nonce, required this.ciphertext});
  final String ephemeralPublicKey;
  final String nonce;
  final String ciphertext;
  Map<String, dynamic> toJson() => {'ephemeralPublicKey': ephemeralPublicKey, 'nonce': nonce, 'ciphertext': ciphertext};
  factory WrappedKeyEnvelope.fromJson(Map<String, dynamic> json) => WrappedKeyEnvelope(
        ephemeralPublicKey: json['ephemeralPublicKey'] as String, nonce: json['nonce'] as String, ciphertext: json['ciphertext'] as String);
}

