import 'dart:io';

import 'package:build/build.dart';
import 'package:i18n_builder/src/functions.dart';
import 'package:path/path.dart' as path;

Builder i18nCleanupBuilder(BuilderOptions options) =>
    I18nCleanupBuilder(options);

class I18nCleanupBuilder implements Builder {
  final BuilderOptions options;

  I18nCleanupBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => {
        '.i18n_builder.json': ['.i18n_cleanup_builder.json']
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final libDir = Directory('lib');
    // Remove the .i18n_builder.json file
    final packageRoot = Directory.current.path;
    final relativePath = buildStep.inputId.path;
    final absolutePath = path.normalize(path.join(packageRoot, relativePath));
    log.info('🧹 Removing ${absolutePath}...');
    final file = File(absolutePath);
    if (file.existsSync()) {
      file.deleteSync();
    } else {
      log.warning('⚠️ File not found...');
    }

    // check if theres a *.i18n_builder.json file in the lib folder
    final allKeys = <String>{};

    // Collect all i18n keys from Dart files in the project
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File) continue;

      if (entity.path.endsWith('.i18n_builder.json')) {
        log.warning('⚠️ is not the last build step');
        return;
      }

      if (entity.path.endsWith('.dart')) {
        final content = await entity.readAsString();
        allKeys.addAll(getI18nKeysFromFileContent(
            content)); // Função importada de functions.dart
      }
    }

    final translationsDir = Directory(
        options.config['translations_dir'] as String? ?? 'assets/translations');

    log.info('🧹 Removing obsolete i18n keys...');

    // Remove obsolete keys from translation files
    final files = translationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      rmvObsoleteKeysFromFile(file, allKeys);
    }
  }
}
