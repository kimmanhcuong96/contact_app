import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/encryption_models.dart';

class CryptoService {
  CryptoService(this._storage);
  final FlutterSecureStorage _storage;
  final _aes = AesGcm.with256bits();
  final _x25519 = X25519();

  Future<SecretKey> newProfileKey() => _aes.newSecretKey();
  Future<String> encodeKey(SecretKey key) async =>
      base64Encode(await key.extractBytes());
  SecretKey decodeKey(String value) => SecretKey(base64Decode(value));

  Future<EncryptedEnvelope> encryptJson(
      Map<String, dynamic> value, SecretKey key) async {
    final box =
        await _aes.encrypt(utf8.encode(jsonEncode(value)), secretKey: key);
    return EncryptedEnvelope(
        nonce: base64Encode(box.nonce),
        ciphertext: base64Encode([...box.cipherText, ...box.mac.bytes]));
  }

  Future<Map<String, dynamic>> decryptJson(
      EncryptedEnvelope envelope, SecretKey key) async {
    final bytes = base64Decode(envelope.ciphertext);
    if (bytes.length < 17) {
      throw const FormatException('Invalid encrypted envelope');
    }
    final box = SecretBox(bytes.sublist(0, bytes.length - 16),
        nonce: base64Decode(envelope.nonce),
        mac: Mac(bytes.sublist(bytes.length - 16)));
    return jsonDecode(utf8.decode(await _aes.decrypt(box, secretKey: key)))
        as Map<String, dynamic>;
  }

  Future<SimplePublicKey> ensureIdentity() async {
    final privateValue = await _storage.read(key: 'identity_private_key');
    final publicValue = await _storage.read(key: 'identity_public_key');
    if (privateValue != null && publicValue != null) {
      return SimplePublicKey(base64Decode(publicValue),
          type: KeyPairType.x25519);
    }
    final pair = await _x25519.newKeyPair();
    final data = await pair.extract();
    await _storage.write(
        key: 'identity_private_key', value: base64Encode(data.bytes));
    await _storage.write(
        key: 'identity_public_key', value: base64Encode(data.publicKey.bytes));
    return data.publicKey;
  }

  Future<String> publicIdentityBase64() async =>
      base64Encode((await ensureIdentity()).bytes);

  Future<WrappedKeyEnvelope> wrapKey(
      SecretKey profileKey, String recipientPublicKey) async {
    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final shared = await _x25519.sharedSecretKey(
        keyPair: ephemeral,
        remotePublicKey: SimplePublicKey(base64Decode(recipientPublicKey),
            type: KeyPairType.x25519));
    final wrappingKey = await _deriveWrappingKey(shared);
    final rawKey = await profileKey.extractBytes();
    final box = await _aes.encrypt(rawKey, secretKey: wrappingKey);
    return WrappedKeyEnvelope(
        ephemeralPublicKey: base64Encode(ephemeralPublic.bytes),
        nonce: base64Encode(box.nonce),
        ciphertext: base64Encode([...box.cipherText, ...box.mac.bytes]));
  }

  Future<SecretKey> unwrapKey(WrappedKeyEnvelope envelope) async {
    final privateValue = await _storage.read(key: 'identity_private_key');
    final publicValue = await _storage.read(key: 'identity_public_key');
    if (privateValue == null || publicValue == null) {
      throw StateError('Encryption identity is unavailable');
    }
    final identity = SimpleKeyPairData(base64Decode(privateValue),
        publicKey: SimplePublicKey(base64Decode(publicValue),
            type: KeyPairType.x25519),
        type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
        keyPair: identity,
        remotePublicKey: SimplePublicKey(
            base64Decode(envelope.ephemeralPublicKey),
            type: KeyPairType.x25519));
    final wrappingKey = await _deriveWrappingKey(shared);
    final bytes = base64Decode(envelope.ciphertext);
    final box = SecretBox(bytes.sublist(0, bytes.length - 16),
        nonce: base64Decode(envelope.nonce),
        mac: Mac(bytes.sublist(bytes.length - 16)));
    return SecretKey(await _aes.decrypt(box, secretKey: wrappingKey));
  }

  Future<SecretKey> _deriveWrappingKey(SecretKey shared) async {
    final digest = await Sha256().hash(await shared.extractBytes());
    return SecretKey(Uint8List.fromList(digest.bytes));
  }
}
