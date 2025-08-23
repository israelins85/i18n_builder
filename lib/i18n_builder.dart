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
        '.dart': ['.i18n_dummy'] // cada .dart tem seu dummy file
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final baseLocale = options.config['base_locale'] as String? ?? 'en-US';
    final translationsDir = Directory(
        options.config['translations_dir'] as String? ?? 'assets/translations');

    log.info('🔍 Building i18n files...');

    // Colete as chaves i18n
    final i18nKeys = await _getI18nKeysFromAsset(buildStep);

    // Atualize os arquivos de tradução
    final files = translationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      final locale = file.uri.pathSegments.last.split('.').first;
      _addI18nKeysToFile(file, i18nKeys, locale, baseLocale);
    }

    // Gere o arquivo .i18n_builder_last_update.json
    // final gitignoreFile = File('.gitignore');
    final dummyId = buildStep.inputId.changeExtension('.i18n_dummy');
    await buildStep.writeAsString(
        dummyId, '{"timestamp":"${DateTime.now().toIso8601String()}"}');

    // if (gitignoreFile.existsSync()) {
    //   final content = gitignoreFile.readAsStringSync();
    //   if (!content.contains(dummyId.path)) {
    //     log.info('🔧 Updating the .gitignore file...');
    //     gitignoreFile.writeAsStringSync('\n # i18n_builder\n${dummyId.path}',
    //         mode: FileMode.append);
    //   }
    // }
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

  Future<Set<String>> _getI18nKeysFromAsset(BuildStep buildStep) async {
    final id = buildStep.inputId;

    // Ignora este arquivo
    if (id.path.endsWith('i18n_builder.dart')) return <String>{};

    // Ignora arquivos que não sejam Dart
    if (!id.path.endsWith('.dart')) return <String>{};

    // Ignora arquivos gerados
    if (id.path.contains('.g.dart') || id.path.contains('.freezed.dart')) {
      return <String>{};
    }

    // Ignora arquivos de teste
    if (id.path.contains('/test/') || id.path.endsWith('_test.dart')) {
      return <String>{};
    }

    // Ignora arquivos temporários de IDEs ou builds
    if (id.path.contains('.dart_tool/') || id.path.contains('build/')) {
      return <String>{};
    }

    // Ignora arquivos de exemplo ou dev-only
    if (id.path.contains('/example/') || id.path.contains('/dev/')) {
      return <String>{};
    }

    final content = await buildStep.readAsString(id);
    return _getI18nKeys(content);
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

    // TODO: can't to this now, because can remove valid keys
    // keys that are not in the current locale will be removed
    // Remove obsolete keys
    // for (final key in currentKeys) {
    //   if (key == '@@locale') continue;
    //   if (keys.contains(key)) continue;
    //   // Ignore nested keys without spaces and well-formed (e.g., auth.error)
    //   final isLikelyStructuredKey =
    //       !key.contains(' ') && key.contains('.') && !key.endsWith('.');
    //   if (isLikelyStructuredKey) continue;
    //   log.info('❌ [$locale] removing obsolete key "$key".');
    //   translations.remove(key);
    //   updated = true;
    // }

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
