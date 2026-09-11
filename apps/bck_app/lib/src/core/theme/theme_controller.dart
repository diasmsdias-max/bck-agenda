import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'bck_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'bck_accent_theme';
  final FlutterSecureStorage _storage;
  BckAccentTheme _accentTheme = BckAccentTheme.gold;

  BckAccentTheme get accentTheme => _accentTheme;

  Future<void> load() async {
    final saved = await _storage.read(key: _storageKey);
    _accentTheme = saved == BckAccentTheme.rose.name
        ? BckAccentTheme.rose
        : BckAccentTheme.gold;
    notifyListeners();
  }

  Future<void> setAccentTheme(BckAccentTheme value) async {
    if (_accentTheme == value) return;
    _accentTheme = value;
    notifyListeners();
    await _storage.write(key: _storageKey, value: value.name);
  }
}
