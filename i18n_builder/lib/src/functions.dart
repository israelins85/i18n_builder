import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';

final i18nPattern = RegExp(r"'((?:[^'\\]|\\.)*)'\s*\.i18n", dotAll: true);

bool hasUnescapedDollar(String str) {
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

String unescape(String input) =>
    input.replaceAll(r"\'", "'").replaceAll(r'\"', '"').replaceAll(r'\\', '\\');

/// Busca uma chave existente que corresponde à chave fornecida (case-insensitive)
String? findExistingKeyIgnoreCase(Map<String, dynamic> map, String key) {
  final lowerKey = key.toLowerCase();
  for (final existingKey in map.keys) {
    if (existingKey.toLowerCase() == lowerKey && existingKey != key) {
      return existingKey;
    }
  }
  return null;
}

Set<String> getI18nKeysFromFileContent(String content) {
  final matches = i18nPattern.allMatches(content);
  return matches
      .map((match) => unescape(match.group(1)!))
      .where((key) => !hasUnescapedDollar(key))
      .toSet();
}

bool ignoreFile(String path) {
  // Ignora arquivos da lib
  if (path.endsWith('lib/i18n_builder.dart')) return true;
  if (path.endsWith('lib/i18n_cleanup_builder.dart')) return true;

  // Ignora arquivos que não sejam Dart
  if (!path.endsWith('.dart')) return true;

  // Ignora arquivos gerados
  if (path.endsWith('.g.dart')) return true;
  if (path.endsWith('.freezed.dart')) return true;

  // Ignora arquivos de teste
  if (path.endsWith('_test.dart')) return true;
  if (path.endsWith('test.dart')) return true;

  // Ignora arquivos temporários de IDEs ou builds
  if (path.endsWith('.dart_tool/')) return true;
  if (path.endsWith('build/')) return true;

  // Ignora arquivos dev-only
  if (path.endsWith('/dev/')) return true;
  if (path.endsWith('/test/')) return true;

  return false;
}

void persistI18nKeys(File file, Map<String, dynamic> translations) {
  if (!file.existsSync()) return;

  final ordered = SplayTreeMap<String, dynamic>.from(translations, (a, b) {
    if (a == '@@locale') return -1;
    if (b == '@@locale') return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  });
  final newContent = const JsonEncoder.withIndent('    ').convert(ordered);
  file.writeAsStringSync(newContent);
}

Future<void> addI18nKeysFromDir(
  Directory dir, {
  required Directory translationsDir,
  required String baseLocale,
  required bool keyIsBaseText,
  bool removeObsoleteKeys = false,
}) async {
  final Set<String> allI18nKeys = {};
  // busco recursivamente todos os arquivos .dart
  // e adiciona as chaves i18n encontradas
  // para o arquivo .json correspondente
  // e remove as chaves obsoletas
  // se removeObsoleteKeys for true
  final dartFiles = await dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final i18nKeys = getI18nKeysFromFileContent(content);
    allI18nKeys.addAll(i18nKeys);
  }

  addI18nKeysToTranslationFiles(
    allI18nKeys,
    translationsDir: translationsDir,
    baseLocale: baseLocale,
    keyIsBaseText: keyIsBaseText,
    removeObsoleteKeys: removeObsoleteKeys,
  );
}

void addI18nKeysFromFileContent(
  String content, {
  required Directory translationsDir,
  required String baseLocale,
  required bool keyIsBaseText,
  bool removeObsoleteKeys = false,
}) {
  final i18nKeys = getI18nKeysFromFileContent(content);

  addI18nKeysToTranslationFiles(
    i18nKeys,
    translationsDir: translationsDir,
    baseLocale: baseLocale,
    keyIsBaseText: keyIsBaseText,
  );
}

void addI18nKeysToTranslationFiles(
  Set<String> keys, {
  required Directory translationsDir,
  required String baseLocale,
  required bool keyIsBaseText,
  bool removeObsoleteKeys = false,
}) {
  final files = translationsDir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.json'),
  );

  for (final file in files) {
    final locale = file.uri.pathSegments.last.split('.').first;
    addI18nKeysToFile(
      file,
      keys,
      locale: locale,
      baseLocale: baseLocale,
      keyIsBaseText: keyIsBaseText,
    );
    if (removeObsoleteKeys) {
      rmvObsoleteKeysFromFile(file, keys);
    }
  }
}

void addI18nKeysToFile(
  File file,
  Set<String> keys, {
  required String locale,
  required String baseLocale,
  required bool keyIsBaseText,
}) {
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

  log.info('🔍 [$locale] Existing keys: ${currentKeys.length - 1}');

  // Add missing keys
  // if (locale == baseLocale) {
  for (final key in keys) {
    // Verifica se já existe uma chave com o mesmo valor (case-insensitive)
    final similarKey = findExistingKeyIgnoreCase(translations, key);
    if (similarKey != null && similarKey != key) {
      log.warning(
        '⚠️  [$locale] Found similar key "$similarKey" for "$key" (different case only).',
      );
    }

    if ((locale.startsWith(baseLocale) || baseLocale.startsWith(locale)) &&
        keyIsBaseText) {
      if (currentKeys.contains(key)) {
        if (translations[key] == key) continue;
        log.info('✅ [$locale] updating key "$key".');
      } else {
        log.info('✅ [$locale] adding key "$key".');
      }
      translations[key] = key;
    } else {
      if (translations[key] != null) continue;
      log.info('✅ [$locale] adding key "$key" with empty value.');
      translations[key] = '';
    }
    updated = true;
  }

  if (translations['@@locale'] != locale) {
    translations['@@locale'] = locale;
    updated = true;
  }

  if (updated) {
    persistI18nKeys(file, translations);
  } else {
    log.info('✅ [$locale] is already up to date.');
  }
}

void rmvObsoleteKeysFromFile(File file, Set<String> keys) {
  if (!file.existsSync()) return;

  final content = file.readAsStringSync();
  Map<String, dynamic> translations = {};
  bool updated = false;
  String locale;

  try {
    translations = jsonDecode(content);
    locale = translations['@@locale'] as String;
  } catch (e) {
    log.severe('❌ [$file.path] Error reading $e');
    return;
  }

  final currentKeys = Set<String>.from(translations.keys);

  // Remove obsolete keys
  for (final key in currentKeys) {
    if (key == '@@locale') continue;
    if (keys.contains(key)) continue;
    // Ignore nested keys without spaces and well-formed (e.g., auth.error)
    final isLikelyStructuredKey =
        !key.contains(' ') &&
        (key.contains('.') || key.contains('_')) &&
        !key.endsWith('.');
    if (isLikelyStructuredKey) continue;
    log.info('❌ [$locale] removing obsolete key "$key".');
    translations.remove(key);
    updated = true;
  }

  if (updated) {
    persistI18nKeys(file, translations);
  } else {
    log.info('✅ [$locale] is already up to date.');
  }
}
