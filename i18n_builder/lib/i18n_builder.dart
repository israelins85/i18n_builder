import 'dart:io';

import 'package:build/build.dart';
import 'package:i18n_builder/src/functions.dart';

Builder i18nBuilder(BuilderOptions options) => I18nBuilder(options);

class I18nBuilder implements Builder {
  final BuilderOptions options;

  I18nBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.i18n_builder.json'], // cada .dart tem seu dummy file
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final baseLocale = options.config['base_locale'] as String? ?? 'en';
    final translationsDir = Directory(
      options.config['translations_dir'] as String? ?? 'assets/translations',
    );
    final keyIsBaseText = options.config['key_is_base_text'] as bool? ?? true;

    if (ignoreFile(buildStep.inputId.path)) return;

    log.info('🔍 Searching for i18n keys in ${buildStep.inputId.path}...');

    // Colete as chaves i18n
    final content = await buildStep.readAsString(buildStep.inputId);

    addI18nKeysFromFileContent(
      content,
      translationsDir: translationsDir,
      baseLocale: baseLocale,
      keyIsBaseText: keyIsBaseText,
    );

    // criar um arquivo .i18n_builder.json para o cleanup rodar
    final outputId = buildStep.allowedOutputs.first;
    log.info('🔧 Writing ${outputId.path}...');
    await buildStep.writeAsString(outputId, content);
  }
}
