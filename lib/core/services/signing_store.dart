import 'package:shared_preferences/shared_preferences.dart';

class SigningStore {
  static const _keystoreKey = 'moonxide.sign.keystore';
  static const _aliasKey = 'moonxide.sign.alias';
  static const _storePasswordKey = 'moonxide.sign.store_password';
  static const _keyPasswordKey = 'moonxide.sign.key_password';

  Future<void> save({required String keystore, required String alias, required String storePassword, required String keyPassword}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keystoreKey, keystore);
    await prefs.setString(_aliasKey, alias);
    await prefs.setString(_storePasswordKey, storePassword);
    await prefs.setString(_keyPasswordKey, keyPassword);
  }

  Future<Map<String, String?>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'keystore': prefs.getString(_keystoreKey),
      'alias': prefs.getString(_aliasKey),
      'storePassword': prefs.getString(_storePasswordKey),
      'keyPassword': prefs.getString(_keyPasswordKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keystoreKey);
    await prefs.remove(_aliasKey);
    await prefs.remove(_storePasswordKey);
    await prefs.remove(_keyPasswordKey);
  }
}