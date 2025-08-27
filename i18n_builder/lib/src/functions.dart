import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';

final i18nPattern = RegExp(
  r"'((?:[^'\\]|\\.)*)'\s*\.i18n",
  dotAll: true,
);

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

Future<Set<String>> getI18nKeysFromAsset(BuildStep buildStep) async {
  final id = buildStep.inputId;

  if (ignoreFile(id.path)) return <String>{};

  final content = await buildStep.readAsString(id);
  return getI18nKeysFromFileContent(content);
}

void persistI18nKeys(File file, Map<String, dynamic> translations) {
  if (!file.existsSync()) return;

  final ordered = SplayTreeMap<String, dynamic>.from(
    translations,
    (a, b) {
      if (a == '@@locale') return -1;
      if (b == '@@locale') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    },
  );
  final newContent = const JsonEncoder.withIndent('    ').convert(ordered);
  file.writeAsStringSync(newContent);
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
    if (locale == baseLocale && keyIsBaseText) {
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
        !key.contains(' ') && key.contains('.') && !key.endsWith('.');
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
