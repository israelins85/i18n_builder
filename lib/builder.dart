import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';

Builder i18nBuilder(BuilderOptions options) => I18nBuilder(options);

class I18nBuilder implements Builder {
  final BuilderOptions options;

  final i18nPattern = RegExp(
    r"'((?:[^'\\]|\\.)*)'\s*(?:\/\/[^\n]*\n|\s)*\.i18n",
    dotAll: true,
  );

  I18nBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': ['i18n_generated.json']
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final baseLocale = options.config['base_locale'] as String? ?? 'en-US';
    final libDir = Directory('lib');
    final translationsDir = Directory(
        options.config['translations_dir'] as String? ?? 'assets/translations');

    log.info('🔍 Building i18n files...');

    // Colete as chaves i18n
    final i18nKeys = _getI18nKeysInDirectory(libDir);

    // Atualize os arquivos de tradução
    final files = translationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      final locale = file.uri.pathSegments.last.split('.').first;
      _addI18nKeysToFile(file, i18nKeys, locale, baseLocale);
    }
  }

  bool _hasUnescapedDollar(String str) {
    for (int i = 0; i < str.length; i++) {
      if (str[i] == r'$') {
        int backslashes = 0;
        int j = i - 1;
        while (j >= 0 && str[j] == r'\\'[0]) {
          backslashes++;
          j--;
        }
        if (backslashes % 2 == 0) {
          log.warning('❌ Unescaped "\$" in "$str"');
          return true; // $ is not escaped
        }
      }
    }
    return false;
  }

  String _unescape(String input) => input
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', '\\');

  Set<String> _getI18nKeys(String content) {
    final matches = i18nPattern.allMatches(content);
    return matches
        .map((match) => _unescape(match.group(1)!))
        .where((key) => !_hasUnescapedDollar(key))
        .toSet();
  }

  Set<String> _getI18nKeysFromFile(File file) {
    final content = file.readAsStringSync();
    return _getI18nKeys(content);
  }

  Set<String> _getI18nKeysInDirectory(Directory dir) {
    final keys = <String>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('.g.dart') &&
          !entity.path.contains('.freezed.dart')) {
        keys.addAll(_getI18nKeysFromFile(entity));
      }
    }
    return keys.toSet();
  }

  void _addI18nKeysToFile(
      File file, Set<String> keys, String locale, String baseLocale) {
    log.info('🔧 [$locale] Updating...');
    if (!file.existsSync()) return;

    final content = file.readAsStringSync();
    Map<String, dynamic> translations = {};
    bool updated = false;

    try {
      translations = jsonDecode(content);
    } catch (e) {
      log.severe('❌ [$locale] Error reading $e');
    }

    final currentKeys = Set<String>.from(translations.keys);
    translations['@@locale'] ??= locale;

    log.info('🔍 [$locale] Founded keys: ${currentKeys.length - 1}');

    // Add missing keys
    if (locale == baseLocale) {
      for (final key in keys) {
        if (currentKeys.contains(key)) {
          if (translations[key] == key) continue;
          log.info('✅ [$locale] updating key "$key".');
        } else {
          log.info('✅ [$locale] adding key "$key".');
        }
        translations[key] = key;
        updated = true;
      }
    }

    // Remove obsolete keys
    for (final key in currentKeys) {
      if (key == '@@locale') continue;
      if (keys.contains(key)) continue;
      // Ignore nested keys without spaces and well-formed (e.g., auth.error)
      final isLikelyStructuredKey =
          !key.contains(' ') && key.contains('.') && !key.endsWith('.');
      if (isLikelyStructuredKey) continue;
      log.info('❌ [$locale] removing obsolete key "$key".');
      translations.remove(key);
      updated = true;
    }

    if (updated) {
      final ordered = SplayTreeMap<String, dynamic>.from(
        translations,
        (a, b) {
          if (a == '@@locale') return -1;
          if (b == '@@locale') return 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        },
      );
      log.info('✅ [$locale] updated with new keys.');
      final newContent = const JsonEncoder.withIndent('    ').convert(ordered);
      file.writeAsStringSync(newContent);
    } else {
      log.info('✅ [$locale] is already up to date.');
    }
  }
}
