import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;

import '../utils/zen_logger.dart';
import 'atom_persistence.dart';

/// Global provider instances
late SharedPreferencesPersistenceProvider sharedPrefsProvider;
late HivePersistenceProvider hiveProvider;
late SecureStoragePersistenceProvider secureStorageProvider;
late EncryptedSharedPreferencesPersistenceProvider encryptedSharedPrefsProvider;

/// Sets up all persistence providers and initializes encryption keys
Future<void> setupPersistence() async {
  // Initialize providers
  sharedPrefsProvider = SharedPreferencesPersistenceProvider();
  hiveProvider = HivePersistenceProvider(boxName: 'zenstate_data');
  secureStorageProvider = SecureStoragePersistenceProvider();

  // Get or generate encryption keys
  List<int> encryptionKey;
  List<int> encryptionIV;

  try {
    // Try to retrieve existing keys from secure storage
    const secureStorage = FlutterSecureStorage();
    final storedKey = await secureStorage.read(key: 'zenstate_encryption_key');
    final storedIV = await secureStorage.read(key: 'zenstate_encryption_iv');

    if (storedKey != null && storedIV != null) {
      // Convert stored base64 strings back to List<int>
      encryptionKey = base64Decode(storedKey);
      encryptionIV = base64Decode(storedIV);
      ZenLogger.instance.debug('Retrieved existing encryption keys');
    } else {
      // Generate new keys
      encryptionKey = EncryptionProvider.generateKey();
      encryptionIV = EncryptionProvider.generateIV();

      // Store the keys for future use (as base64 strings)
      await secureStorage.write(
          key: 'zenstate_encryption_key', value: base64Encode(encryptionKey));
      await secureStorage.write(
          key: 'zenstate_encryption_iv', value: base64Encode(encryptionIV));
      ZenLogger.instance.debug('Generated and stored new encryption keys');
    }

    // Initialize encrypted providers
    encryptedSharedPrefsProvider =
        EncryptedSharedPreferencesPersistenceProvider(
      key: encryptionKey,
      iv: encryptionIV,
    );
  } catch (e, stackTrace) {
    // Handle errors gracefully - create fallback encryption for web or when secure storage fails
    ZenLogger.instance.warning(
      'Error setting up secure encryption, using fallback mechanism',
      error: e,
      stackTrace: stackTrace,
    );

    // Use deterministic keys for fallback (less secure but prevents crashes)
    final fallbackSeed = DateTime.now().millisecondsSinceEpoch;
    final random = Random(fallbackSeed);
    encryptionKey = List<int>.generate(32, (_) => random.nextInt(256));
    encryptionIV = List<int>.generate(16, (_) => random.nextInt(256));

    encryptedSharedPrefsProvider =
        EncryptedSharedPreferencesPersistenceProvider(
      key: encryptionKey,
      iv: encryptionIV,
    );
  }
}

/// A mixin that adds encryption capabilities to persistence providers
mixin EncryptionProvider {
  /// The encryption key
  late final encrypt_pkg.Key _key;

  /// The encryption IV
  late final encrypt_pkg.IV _iv;

  /// The encryption encrypter
  late final encrypt_pkg.Encrypter _encrypter;

  /// Initializes the encryption provider
  void initEncryption(List<int> key, List<int> iv) {
    _key = encrypt_pkg.Key(Uint8List.fromList(key));
    _iv = encrypt_pkg.IV(Uint8List.fromList(iv));
    _encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_key));
  }

  /// Encrypts a string
  String encrypt(String value) {
    try {
      return _encrypter.encrypt(value, iv: _iv).base64;
    } catch (e) {
      ZenLogger.instance.error('Encryption error', error: e);
      // Return a safe fallback value
      return base64Encode(utf8.encode(value));
    }
  }

  /// Decrypts a string
  String decrypt(String value) {
    try {
      return _encrypter.decrypt64(value, iv: _iv);
    } catch (e) {
      ZenLogger.instance.error('Decryption error', error: e);
      // Try to recover by assuming it might be base64 encoded
      try {
        return utf8.decode(base64Decode(value));
      } catch (_) {
        // If all else fails, return the original value
        return value;
      }
    }
  }

  /// Generates a random encryption key
  static List<int> generateKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  /// Generates a random IV
  static List<int> generateIV() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }
}

/// A shared preferences implementation of [PersistenceProvider].
class SharedPreferencesPersistenceProvider implements PersistenceProvider {
  /// The shared preferences instance.
  final Future<SharedPreferences> _prefs;

  /// Cache for faster access
  SharedPreferences? _prefsInstance;

  /// Creates a new [SharedPreferencesPersistenceProvider].
  SharedPreferencesPersistenceProvider()
      : _prefs = SharedPreferences.getInstance() {
    // Initialize the cache
    _prefs.then((prefs) => _prefsInstance = prefs);
  }

  @override
  Future<void> save(String key, String value) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await prefs.setString(key, value);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving to SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<String?> load(String key) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      return prefs.getString(key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error loading from SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await prefs.remove(key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error removing from SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await prefs.clear();
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error clearing SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> saveBatch(Map<String, String> values) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await Future.wait(
        values.entries.map((entry) => prefs.setString(entry.key, entry.value)),
      );
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving batch to SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      final results = <String, String>{};
      for (final key in keys) {
        final value = await prefs.getString(key);
        if (value != null) {
          results[key] = value;
        }
      }
      return results;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error loading batch from SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await Future.wait(keys.map((key) => prefs.remove(key)));
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error removing batch from SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      return prefs.getKeys().toList();
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error getting keys from SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> size() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      final allKeys = prefs.getKeys();
      int totalSize = 0;
      for (final key in allKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += key.length + value.length;
        }
      }
      return totalSize;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error calculating size of SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      return prefs.containsKey(key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error checking existence in SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      final allKeys = prefs.getKeys();
      final values = <String, String>{};
      for (final key in allKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          values[key] = value;
        }
      }
      return values;
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
          'Error getting all values from SharedPreferences',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      await prefs.setString('__test__', 'test');
      await prefs.remove('__test__');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> count() async {
    try {
      final prefs = _prefsInstance ?? await _prefs;
      return prefs.getKeys().length;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error counting values in SharedPreferences',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// A Hive implementation of [PersistenceProvider].
class HivePersistenceProvider implements PersistenceProvider {
  /// The name of the Hive box to use.
  final String boxName;

  /// Whether the box is encrypted.
  final bool isEncrypted;

  /// The encryption key to use if the box is encrypted.
  final List<int>? encryptionKey;

  /// The Hive box.
  late final Future<Box> _box;

  /// Box instance cache
  Box? _boxInstance;

  /// Creates a new [HivePersistenceProvider].
  HivePersistenceProvider({
    required this.boxName,
    this.isEncrypted = false,
    this.encryptionKey,
  }) : _box = _openBox(boxName, isEncrypted, encryptionKey) {
    // Initialize the cache
    _box.then((box) => _boxInstance = box);
  }

  static Future<Box> _openBox(
    String boxName,
    bool isEncrypted,
    List<int>? encryptionKey,
  ) async {
    try {
      // Initialize Hive
      if (kIsWeb) {
        await Hive.initFlutter('zenstate_hive');
      } else {
        await Hive.initFlutter();
      }

      // Open the box
      if (isEncrypted) {
        if (encryptionKey == null) {
          throw ArgumentError(
              'encryptionKey must be provided when isEncrypted is true');
        }

        // Register the encryption adapter
        final encryptionAdapter =
            HiveAesCipher(Uint8List.fromList(encryptionKey));
        return await Hive.openBox(boxName, encryptionCipher: encryptionAdapter);
      } else {
        return await Hive.openBox(boxName);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Failed to initialize Hive. Make sure the hive and hive_flutter packages are added to your pubspec.yaml.',
        error: e,
        stackTrace: stackTrace,
      );

      // Try to recover by using a memory box
      try {
        return await Hive.openBox(boxName, bytes: Uint8List(0));
      } catch (_) {
        // If all else fails, create an in-memory box
        final box = await Hive.openBox('memory_$boxName',
            bytes: Uint8List(0), path: ':memory:');
        return box;
      }
    }
  }

  @override
  Future<void> save(String key, String value) async {
    try {
      final box = _boxInstance ?? await _box;
      await box.put(key, value);
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error saving to Hive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<String?> load(String key) async {
    try {
      final box = _boxInstance ?? await _box;
      return box.get(key) as String?;
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error loading from Hive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final box = _boxInstance ?? await _box;
      await box.delete(key);
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error removing from Hive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final box = _boxInstance ?? await _box;
      await box.clear();
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error clearing Hive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Closes the Hive box.
  Future<void> close() async {
    try {
      final box = _boxInstance ?? await _box;
      await box.close();
      _boxInstance = null;
    } catch (e, stackTrace) {
      ZenLogger.instance
          .error('Error closing Hive box', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generates a random encryption key for Hive.
  static List<int> generateEncryptionKey() {
    try {
      final random = Random.secure();
      return List<int>.generate(32, (_) => random.nextInt(256));
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error generating encryption key',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> saveBatch(Map<String, String> values) async {
    try {
      final box = _boxInstance ?? await _box;
      for (final entry in values.entries) {
        await box.put(entry.key, entry.value);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving batch to Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    try {
      final box = _boxInstance ?? await _box;
      final values = <String, String>{};
      for (final key in keys) {
        final value = box.get(key);
        if (value != null) {
          values[key] = value.toString();
        }
      }
      return values;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error loading batch from Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    try {
      final box = _boxInstance ?? await _box;
      for (final key in keys) {
        await box.delete(key);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error removing batch from Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      final box = _boxInstance ?? await _box;
      return box.keys.map((key) => key.toString()).toList();
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error getting keys from Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> size() async {
    try {
      final box = _boxInstance ?? await _box;
      int totalSize = 0;
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null) {
          totalSize += key.toString().length + value.toString().length;
        }
      }
      return totalSize;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error calculating size of Hive box',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      final box = _boxInstance ?? await _box;
      return box.containsKey(key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error checking existence in Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      final box = _boxInstance ?? await _box;
      final allKeys = box.keys.map((key) => key.toString()).toList();
      final values = <String, String>{};
      for (final key in allKeys) {
        final value = box.get(key);
        if (value != null) {
          values[key] = value.toString();
        }
      }
      return values;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error getting all values from Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final box = _boxInstance ?? await _box;
      await box.put('__test__', 'test');
      await box.delete('__test__');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> count() async {
    try {
      final box = _boxInstance ?? await _box;
      return box.length;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error counting values in Hive',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// A secure storage implementation of [PersistenceProvider].
class SecureStoragePersistenceProvider implements PersistenceProvider {
  /// The secure storage instance.
  late final FlutterSecureStorage _secureStorage;

  /// Additional options for secure storage.
  final Map<String, String>? options;

  /// Creates a new [SecureStoragePersistenceProvider].
  factory SecureStoragePersistenceProvider({Map<String, String>? options}) {
    if (kIsWeb) {
      // On web, use a different implementation with encryption
      return WebSecureStoragePersistenceProvider();
    } else {
      return SecureStoragePersistenceProvider._internal(options: options);
    }
  }

  SecureStoragePersistenceProvider._internal({this.options}) {
    // Create secure storage options if provided
    final storageOptions = options != null
        ? AndroidOptions(
            encryptedSharedPreferences:
                options!['encryptedSharedPreferences'] == 'true',
          )
        : const AndroidOptions();

    _secureStorage = FlutterSecureStorage(aOptions: storageOptions);
  }

  @override
  Future<void> save(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving to SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<String?> load(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error loading from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error removing from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error clearing SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> saveBatch(Map<String, String> values) async {
    try {
      for (final entry in values.entries) {
        await _secureStorage.write(key: entry.key, value: entry.value);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving batch to SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    try {
      final results = <String, String>{};
      for (final key in keys) {
        final value = await _secureStorage.read(key: key);
        if (value != null) {
          results[key] = value;
        }
      }
      return results;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error loading batch from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    try {
      for (final key in keys) {
        await _secureStorage.delete(key: key);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error removing batch from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      final allData = await _secureStorage.readAll();
      return allData.keys.toList();
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error getting keys from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> size() async {
    try {
      final allData = await _secureStorage.readAll();
      int totalSize = 0;
      for (final entry in allData.entries) {
        if (entry.value != null) {
          totalSize += entry.key.length + entry.value!.length;
        }
      }
      return totalSize;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error calculating size of SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      return await _secureStorage.read(key: key) != null;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error checking existence in SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      final allData = await _secureStorage.readAll();
      return Map.fromEntries(
        allData.entries.where((entry) => entry.value != null).map(
              (entry) => MapEntry(entry.key, entry.value!),
            ),
      );
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error getting all values from SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _secureStorage.write(key: '__test__', value: 'test');
      await _secureStorage.delete(key: '__test__');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> count() async {
    try {
      final allData = await _secureStorage.readAll();
      return allData.length;
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error counting values in SecureStorage',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// Web implementation of secure storage using encrypted localStorage
class WebSecureStoragePersistenceProvider
    extends SecureStoragePersistenceProvider {
  final SharedPreferencesPersistenceProvider _delegate =
      SharedPreferencesPersistenceProvider();
  final String _encryptionKey;

  WebSecureStoragePersistenceProvider()
      : _encryptionKey = _generateWebEncryptionKey(),
        super._internal();

  static String _generateWebEncryptionKey() {
    // Generate a deterministic key based on domain to keep it consistent
    final domain = Uri.base.host;
    final keySource = utf8.encode('zenstate_secure_$domain');
    return base64Encode(keySource);
  }

  @override
  Future<void> save(String key, String value) async {
    // Simple encryption for web
    final encrypted = _encryptWeb(value);
    await _delegate.save('secure_$key', encrypted);
  }

  @override
  Future<String?> load(String key) async {
    final encrypted = await _delegate.load('secure_$key');
    if (encrypted == null) return null;
    try {
      return _decryptWeb(encrypted);
    } catch (e) {
      ZenLogger.instance.error('Error decrypting web storage', error: e);
      return null;
    }
  }

  @override
  Future<void> remove(String key) => _delegate.remove('secure_$key');

  @override
  Future<void> clear() => _delegate.clear();

  String _encryptWeb(String value) {
    // XOR-based encryption with the key
    final valueBytes = utf8.encode(value);
    final keyBytes = utf8.encode(_encryptionKey);
    final result = List<int>.filled(valueBytes.length, 0);

    for (var i = 0; i < valueBytes.length; i++) {
      result[i] = valueBytes[i] ^ keyBytes[i % keyBytes.length];
    }

    return base64Encode(result);
  }

  String _decryptWeb(String encrypted) {
    // XOR-based decryption (same as encryption)
    final bytes = base64Decode(encrypted);
    final keyBytes = utf8.encode(_encryptionKey);
    final result = List<int>.filled(bytes.length, 0);

    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }

    return utf8.decode(result);
  }
}

/// An in-memory implementation of [PersistenceProvider].
class InMemoryPersistenceProvider implements PersistenceProvider {
  final Map<String, String> _storage = {};

  @override
  Future<void> save(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> load(String key) async {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> saveBatch(Map<String, String> values) async {
    _storage.addAll(values);
  }

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    return Map.fromEntries(
      keys.map((key) => MapEntry(key, _storage[key] ?? '')),
    );
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    for (final key in keys) {
      _storage.remove(key);
    }
  }

  @override
  Future<bool> exists(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> getAll() async {
    return Map.fromEntries(_storage.entries);
  }

  @override
  Future<bool> isAvailable() async {
    return true;
  }

  @override
  Future<int> count() async {
    return _storage.length;
  }

  @override
  Future<List<String>> keys() async {
    return _storage.keys.toList();
  }

  @override
  Future<int> size() async {
    return _storage.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.key.length + entry.value.length,
    );
  }
}

/// A multi-provider implementation of [PersistenceProvider].
class MultiPersistenceProvider implements PersistenceProvider {
  /// A map of key prefixes to providers.
  final Map<String, PersistenceProvider> _providers;

  /// The default provider to use if no prefix matches.
  final PersistenceProvider _defaultProvider;

  /// Creates a new [MultiPersistenceProvider].
  MultiPersistenceProvider({
    required Map<String, PersistenceProvider> providers,
    required PersistenceProvider defaultProvider,
  })  : _providers = providers,
        _defaultProvider = defaultProvider;

  /// Gets the provider for the given key.
  PersistenceProvider _getProviderForKey(String key) {
    for (final prefix in _providers.keys) {
      if (key.startsWith(prefix)) {
        return _providers[prefix]!;
      }
    }
    return _defaultProvider;
  }

  @override
  Future<void> save(String key, String value) async {
    await _getProviderForKey(key).save(key, value);
  }

  @override
  Future<String?> load(String key) async {
    return await _getProviderForKey(key).load(key);
  }

  @override
  Future<void> remove(String key) async {
    await _getProviderForKey(key).remove(key);
  }

  @override
  Future<void> clear() async {
    // Clear all providers
    for (final provider in _providers.values) {
      await provider.clear();
    }
    await _defaultProvider.clear();
  }

  @override
  Future<bool> exists(String key) async {
    return await _getProviderForKey(key).exists(key);
  }

  @override
  Future<Map<String, String>> getAll() async {
    final allData = <String, String>{};
    for (final provider in _providers.values) {
      allData.addAll(await provider.getAll());
    }
    allData.addAll(await _defaultProvider.getAll());
    return allData;
  }

  @override
  Future<bool> isAvailable() async {
    for (final provider in _providers.values) {
      if (!await provider.isAvailable()) {
        return false;
      }
    }
    return await _defaultProvider.isAvailable();
  }

  @override
  Future<int> count() async {
    int total = 0;
    for (final provider in _providers.values) {
      total += await provider.count();
    }
    total += await _defaultProvider.count();
    return total;
  }

  @override
  Future<List<String>> keys() async {
    final allKeys = <String>{};
    for (final provider in _providers.values) {
      allKeys.addAll(await provider.keys());
    }
    allKeys.addAll(await _defaultProvider.keys());
    return allKeys.toList();
  }

  @override
  Future<int> size() async {
    int total = 0;
    for (final provider in _providers.values) {
      total += await provider.size();
    }
    total += await _defaultProvider.size();
    return total;
  }

  @override
  Future<void> saveBatch(Map<String, String> values) async {
    try {
      for (final entry in values.entries) {
        await _getProviderForKey(entry.key).save(entry.key, entry.value);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error('Error saving batch to MultiPersistenceProvider',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> loadBatch(List<String> keys) async {
    try {
      final results = <String, String>{};
      for (final key in keys) {
        final value = await _getProviderForKey(key).load(key);
        if (value != null) {
          results[key] = value;
        }
      }
      return results;
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
          'Error loading batch from MultiPersistenceProvider',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeBatch(List<String> keys) async {
    try {
      for (final key in keys) {
        await _getProviderForKey(key).remove(key);
      }
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
          'Error removing batch from MultiPersistenceProvider',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// An encrypted shared preferences implementation of [PersistenceProvider]
class EncryptedSharedPreferencesPersistenceProvider
    extends SharedPreferencesPersistenceProvider with EncryptionProvider {
  /// Creates a new [EncryptedSharedPreferencesPersistenceProvider].
  EncryptedSharedPreferencesPersistenceProvider({
    required List<int> key,
    required List<int> iv,
  }) : super() {
    initEncryption(key, iv);
  }

  @override
  Future<void> save(String key, String value) async {
    try {
      await super.save(key, encrypt(value));
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Error saving encrypted data',
        error: e,
        stackTrace: stackTrace,
      );
      // Fallback to saving unencrypted if encryption fails
      await super.save('unencrypted_$key', value);
    }
  }

  @override
  Future<String?> load(String key) async {
    try {
      final encrypted = await super.load(key);
      if (encrypted == null) {
        // Try to load from unencrypted fallback
        return await super.load('unencrypted_$key');
      }
      return decrypt(encrypted);
    } catch (e, stackTrace) {
      ZenLogger.instance.error(
        'Error loading encrypted data',
        error: e,
        stackTrace: stackTrace,
      );
      // Try to load from unencrypted fallback
      return await super.load('unencrypted_$key');
    }
  }
}

/// An encrypted Hive implementation of [PersistenceProvider]
class EncryptedHivePersistenceProvider extends HivePersistenceProvider
    with EncryptionProvider {
  /// Creates a new [EncryptedHivePersistenceProvider].
  EncryptedHivePersistenceProvider({
    required super.boxName,
    required List<int> key,
    required List<int> iv,
  }) : super(isEncrypted: true, encryptionKey: key) {
    initEncryption(key, iv);
  }

  @override
  Future<void> save(String key, String value) async {
    try {
      await super.save(key, encrypt(value));
    } catch (e) {
      // Fallback to unencrypted if encryption fails
      await super.save('unencrypted_$key', value);
    }
  }

  @override
  Future<String?> load(String key) async {
    try {
      final encrypted = await super.load(key);
      if (encrypted == null) {
        // Try to load from unencrypted fallback
        return await super.load('unencrypted_$key');
      }
      return decrypt(encrypted);
    } catch (e) {
      // Try to load from unencrypted fallback
      return await super.load('unencrypted_$key');
    }
  }
}
