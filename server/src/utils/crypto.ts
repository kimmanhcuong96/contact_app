const encoder = new TextEncoder();

export const SERVER_ENCRYPTION_FORMAT = 'nexbook-server-v1' as const;

export type ServerEncryptedEnvelope = {
  format: typeof SERVER_ENCRYPTION_FORMAT;
  algorithm: 'AES-256-GCM';
  keyId: string;
  kdf: { algorithm: 'HKDF-SHA-256'; salt: string };
  nonce: string;
  ciphertext: string;
};

export class LegacyCiphertextError extends Error {
  constructor() { super('Profile data must be migrated from client-side encryption'); }
}

const toBase64Url = (value: Uint8Array): string =>
  btoa(String.fromCharCode(...value)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

const fromBase64 = (value: string): ArrayBuffer => {
  const normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  try {
    const decoded = atob(padded);
    const result = new ArrayBuffer(decoded.length);
    const bytes = new Uint8Array(result);
    for (let index = 0; index < decoded.length; index++) bytes[index] = decoded.charCodeAt(index);
    return result;
  } catch {
    throw new Error('Invalid data encryption key encoding');
  }
};

const isServerEnvelope = (value: unknown): value is ServerEncryptedEnvelope => {
  if (!value || typeof value !== 'object') return false;
  const envelope = value as Partial<ServerEncryptedEnvelope>;
  return envelope.format === SERVER_ENCRYPTION_FORMAT && envelope.algorithm === 'AES-256-GCM'
    && typeof envelope.keyId === 'string' && envelope.kdf?.algorithm === 'HKDF-SHA-256'
    && typeof envelope.kdf.salt === 'string' && typeof envelope.nonce === 'string'
    && typeof envelope.ciphertext === 'string';
};

export const needsServerEncryptionMigration = (value: unknown): boolean => !isServerEnvelope(value);

export class DataEncryptionService {
  private readonly activeKeyId: string;
  private readonly keyRing: Map<string, string>;

  constructor(activeKey: string, activeKeyId = 'v1', previousKeys?: string) {
    if (!activeKey) throw new Error('DATA_ENCRYPTION_KEY is required');
    if (!/^[a-zA-Z0-9._-]{1,64}$/.test(activeKeyId)) throw new Error('Invalid DATA_ENCRYPTION_KEY_ID');
    this.activeKeyId = activeKeyId;
    this.keyRing = new Map([[activeKeyId, activeKey]]);
    if (previousKeys) {
      let parsed: unknown;
      try { parsed = JSON.parse(previousKeys); } catch { throw new Error('DATA_ENCRYPTION_PREVIOUS_KEYS must be valid JSON'); }
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('DATA_ENCRYPTION_PREVIOUS_KEYS must be a JSON object');
      for (const [keyId, key] of Object.entries(parsed)) {
        if (typeof key !== 'string' || !/^[a-zA-Z0-9._-]{1,64}$/.test(keyId)) throw new Error('Invalid previous data encryption key');
        if (!this.keyRing.has(keyId)) this.keyRing.set(keyId, key);
      }
    }
    for (const key of this.keyRing.values()) {
      if (fromBase64(key).byteLength !== 32) throw new Error('Data encryption keys must contain exactly 32 random bytes');
    }
  }

  async encrypt(value: unknown, ownerId: string, clientId: string, version: number): Promise<ServerEncryptedEnvelope> {
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const key = await this.deriveKey(this.keyRing.get(this.activeKeyId)!, salt, ownerId, clientId);
    const ciphertext = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: nonce.buffer, additionalData: this.aad(ownerId, clientId, version) },
      key,
      encoder.encode(JSON.stringify(value)),
    );
    return {
      format: SERVER_ENCRYPTION_FORMAT,
      algorithm: 'AES-256-GCM',
      keyId: this.activeKeyId,
      kdf: { algorithm: 'HKDF-SHA-256', salt: toBase64Url(salt) },
      nonce: toBase64Url(nonce),
      ciphertext: toBase64Url(new Uint8Array(ciphertext)),
    };
  }

  async decrypt(value: unknown, ownerId: string, clientId: string, version: number): Promise<unknown> {
    if (!isServerEnvelope(value)) throw new LegacyCiphertextError();
    const rootKey = this.keyRing.get(value.keyId);
    if (!rootKey) throw new Error(`Data encryption key '${value.keyId}' is unavailable`);
    const salt = fromBase64(value.kdf.salt);
    const nonce = fromBase64(value.nonce);
    if (salt.byteLength !== 16 || nonce.byteLength !== 12) throw new Error('Invalid encrypted profile envelope');
    const key = await this.deriveKey(rootKey, salt, ownerId, clientId);
    const plaintext = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: nonce, additionalData: this.aad(ownerId, clientId, version) },
      key,
      fromBase64(value.ciphertext),
    );
    return JSON.parse(new TextDecoder().decode(plaintext));
  }

  private async deriveKey(rootKey: string, salt: BufferSource, ownerId: string, clientId: string): Promise<CryptoKey> {
    const material = await crypto.subtle.importKey('raw', fromBase64(rootKey), 'HKDF', false, ['deriveKey']);
    return crypto.subtle.deriveKey(
      { name: 'HKDF', hash: 'SHA-256', salt, info: encoder.encode(`nexbook/profile/${ownerId}/${clientId}`) },
      material,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt'],
    );
  }

  private aad(ownerId: string, clientId: string, version: number): ArrayBuffer {
    return encoder.encode(JSON.stringify({ format: SERVER_ENCRYPTION_FORMAT, ownerId, clientId, version })).buffer;
  }
}

export const randomToken = (bytes = 32): string => {
  const value = crypto.getRandomValues(new Uint8Array(bytes));
  return toBase64Url(value);
};

export const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
};

