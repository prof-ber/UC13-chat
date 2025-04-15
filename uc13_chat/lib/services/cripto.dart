import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithRandom;
import 'package:http/http.dart' as http;

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  factory EncryptionService() {
    return _instance;
  }

  EncryptionService._internal();

  // Generate RSA key pair for a user
  Future<Map<String, String>> generateKeyPair() async {
    // Generate a secure random number generator
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    // Create an RSA key generator and initialize it
    final keyGen =
        RSAKeyGenerator()..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            secureRandom,
          ),
        );

    // Generate the key pair
    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    // Convert to PEM format
    final publicKeyString = encodePublicKeyToPem(publicKey);
    final privateKeyString = encodePrivateKeyToPem(privateKey);

    return {'publicKey': publicKeyString, 'privateKey': privateKeyString};
  }

  // Store keys securely
  Future<void> storeKeys(String userId, Map<String, String> keyPair) async {
    await _secureStorage.write(
      key: '${userId}_public_key',
      value: keyPair['publicKey'],
    );
    await _secureStorage.write(
      key: '${userId}_private_key',
      value: keyPair['privateKey'],
    );
  }

  // Retrieve public key
  Future<String?> getPublicKey(String userId) async {
    return await _secureStorage.read(key: '${userId}_public_key');
  }

  // Retrieve private key
  Future<String?> getPrivateKey(String userId) async {
    return await _secureStorage.read(key: '${userId}_private_key');
  }

  // Store contact's public key
  Future<void> storeContactPublicKey(String contactId, String publicKey) async {
    await _secureStorage.write(
      key: 'contact_${contactId}_public_key',
      value: publicKey,
    );
  }

  // Retrieve contact's public key
  Future<String?> getContactPublicKey(String contactId) async {
    return await _secureStorage.read(key: 'contact_${contactId}_public_key');
  }

  // Check if we have keys for a contact
  Future<bool> hasKeysForContact(String contactId) async {
    final contactPublicKey = await getContactPublicKey(contactId);
    return contactPublicKey != null;
  }

  // Exchange keys with a contact
  Future<bool> exchangeKeys(
    String userId,
    String contactId,
    String token,
  ) async {
    try {
      // Check if we already have our own keys
      String? privateKey = await getPrivateKey(userId);
      String? publicKey = await getPublicKey(userId);

      // Generate keys if we don't have them
      if (privateKey == null || publicKey == null) {
        final keyPair = await generateKeyPair();
        await storeKeys(userId, keyPair);
        publicKey = keyPair['publicKey'];
      }

      // Send our public key to the server
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/keys/exchange'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'recipientId': contactId, 'publicKey': publicKey}),
      );

      if (response.statusCode == 200) {
        // Get the contact's public key from the response
        final responseData = json.decode(response.body);
        final contactPublicKey = responseData['recipientPublicKey'];

        if (contactPublicKey != null) {
          // Store the contact's public key
          await storeContactPublicKey(contactId, contactPublicKey);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error exchanging keys: $e');
      return false;
    }
  }

  // Encrypt a message using recipient's public key
  Future<String> encryptMessage(String message, String recipientId) async {
    final recipientPublicKeyPem = await getContactPublicKey(recipientId);
    if (recipientPublicKeyPem == null) {
      throw Exception('No public key found for recipient');
    }

    final publicKey = parsePublicKeyFromPem(recipientPublicKeyPem);

    // Use AES for message encryption (hybrid encryption)
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    // Encrypt the message with AES
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encryptedMessage = encrypter.encrypt(message, iv: iv);

    // Encrypt the AES key with RSA
    final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));
    final encryptedKey = rsaEncrypter.encrypt(base64.encode(aesKey.bytes));

    // Combine everything into a single package
    final Map<String, String> encryptedPackage = {
      'encryptedKey': encryptedKey.base64,
      'iv': base64.encode(iv.bytes),
      'encryptedMessage': encryptedMessage.base64,
    };

    return jsonEncode(encryptedPackage);
  }

  // Decrypt a message using user's private key
  Future<String> decryptMessage(String encryptedPackage, String userId) async {
    final privateKeyPem = await getPrivateKey(userId);
    if (privateKeyPem == null) {
      throw Exception('No private key found for user');
    }

    final privateKey = parsePrivateKeyFromPem(privateKeyPem);

    // Parse the encrypted package
    final Map<String, dynamic> package = jsonDecode(encryptedPackage);
    final encryptedKey = encrypt.Encrypted.fromBase64(package['encryptedKey']);
    final iv = encrypt.IV.fromBase64(package['iv']);
    final encryptedMessage = encrypt.Encrypted.fromBase64(
      package['encryptedMessage'],
    );

    // Decrypt the AES key with RSA
    final rsaDecrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
    final keyBytes = base64.decode(rsaDecrypter.decrypt(encryptedKey));
    final aesKey = encrypt.Key(Uint8List.fromList(keyBytes));

    // Decrypt the message with AES
    final decrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final decryptedMessage = decrypter.decrypt(encryptedMessage, iv: iv);

    return decryptedMessage;
  }

  // Helper methods for PEM encoding/decoding
  String encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence();
    final algorithm = ASN1Sequence();
    final algorithmAsn1Obj = ASN1Object.fromBytes(
      Uint8List.fromList([
        0x06,
        0x09,
        0x2A,
        0x86,
        0x48,
        0x86,
        0xF7,
        0x0D,
        0x01,
        0x01,
        0x01,
      ]),
    );
    final paramsAsn1Obj = ASN1Object.fromBytes(
      Uint8List.fromList([0x05, 0x00]),
    );
    algorithm.add(algorithmAsn1Obj);
    algorithm.add(paramsAsn1Obj);

    algorithmSeq.add(algorithm);

    final publicKeyBytes = _getPublicKeyBytes(publicKey);
    final publicKeyAsn1Obj = ASN1BitString(publicKeyBytes);

    algorithmSeq.add(publicKeyAsn1Obj);

    final dataBase64 = base64.encode(algorithmSeq.encodedBytes);

    return """-----BEGIN PUBLIC KEY-----\r\n$dataBase64\r\n-----END PUBLIC KEY-----""";
  }

  Uint8List _getPublicKeyBytes(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus;
    final exponent = publicKey.exponent;

    final innerSeq = ASN1Sequence();
    // Fix: Use BigInt directly instead of converting to bytes first
    innerSeq.add(ASN1Integer(modulus!));
    innerSeq.add(ASN1Integer(exponent!));

    return innerSeq.encodedBytes;
  }

  String encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final version = ASN1Integer(BigInt.from(0));
    final modulus = ASN1Integer(privateKey.modulus!);
    final publicExponent = ASN1Integer(privateKey.exponent!);
    final privateExponent = ASN1Integer(privateKey.privateExponent!);
    final p = ASN1Integer(privateKey.p!);
    final q = ASN1Integer(privateKey.q!);
    final dP = ASN1Integer(
      privateKey.privateExponent! % (privateKey.p! - BigInt.from(1)),
    );
    final dQ = ASN1Integer(
      privateKey.privateExponent! % (privateKey.q! - BigInt.from(1)),
    );
    final qInv = ASN1Integer(privateKey.q!.modInverse(privateKey.p!));

    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(version);
    topLevelSeq.add(modulus);
    topLevelSeq.add(publicExponent);
    topLevelSeq.add(privateExponent);
    topLevelSeq.add(p);
    topLevelSeq.add(q);
    topLevelSeq.add(dP);
    topLevelSeq.add(dQ);
    topLevelSeq.add(qInv);

    final dataBase64 = base64.encode(topLevelSeq.encodedBytes);

    return """-----BEGIN RSA PRIVATE KEY-----\r\n$dataBase64\r\n-----END RSA PRIVATE KEY-----""";
  }

  RSAPublicKey parsePublicKeyFromPem(String pemString) {
    pemString = pemString.replaceAll('-----BEGIN PUBLIC KEY-----', '');
    pemString = pemString.replaceAll('-----END PUBLIC KEY-----', '');
    pemString = pemString.replaceAll('\r', '');
    pemString = pemString.replaceAll('\n', '');

    final bytes = base64.decode(pemString);
    final asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    final subjectPublicKeyInfo = topLevelSeq.elements[1] as ASN1BitString;

    final subjectPublicKeyAsn1Parser = ASN1Parser(
      Uint8List.fromList(subjectPublicKeyInfo.contentBytes()!),
    );
    final publicKeySeq =
        subjectPublicKeyAsn1Parser.nextObject() as ASN1Sequence;

    final modulus = (publicKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent =
        (publicKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;

    return RSAPublicKey(modulus!, exponent!);
  }

  RSAPrivateKey parsePrivateKeyFromPem(String pemString) {
    pemString = pemString.replaceAll('-----BEGIN RSA PRIVATE KEY-----', '');
    pemString = pemString.replaceAll('-----END RSA PRIVATE KEY-----', '');
    pemString = pemString.replaceAll('\r', '');
    pemString = pemString.replaceAll('\n', '');

    final bytes = base64.decode(pemString);
    final asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    final version = (topLevelSeq.elements[0] as ASN1Integer).valueAsBigInteger;
    final modulus = (topLevelSeq.elements[1] as ASN1Integer).valueAsBigInteger;
    final publicExponent =
        (topLevelSeq.elements[2] as ASN1Integer).valueAsBigInteger;
    final privateExponent =
        (topLevelSeq.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (topLevelSeq.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (topLevelSeq.elements[5] as ASN1Integer).valueAsBigInteger;

    return RSAPrivateKey(modulus!, privateExponent!, p, q);
  }

  Uint8List _bigIntToBytes(BigInt bigInt) {
    var hexString = bigInt.toRadixString(16);
    if (hexString.length % 2 != 0) {
      hexString = '0$hexString';
    }

    final bytes = <int>[];
    for (var i = 0; i < hexString.length; i += 2) {
      bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
  }
}
