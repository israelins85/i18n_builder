import 'dart:io';
import 'package:i18n_builder/src/functions.dart';

void main(List<String> args) {
  if (args.length < 2) {
    print(
      'Usage: dart run bin/i18n_standalone.dart <source_dir> <translations_dir> [options]',
    );
    print('Options:');
    print('  --base-locale <locale>     Base locale (default: en)');
    print('  --key-is-base-text    Use key as base text (default: false)');
    print('  --remove-obsolete     Remove obsolete keys (default: false)');
    exit(1);
  }

  final sourceDir = Directory(args[0]);
  final translationsDir = Directory(args[1]);

  // Parse baseLocale from args
  String baseLocale = 'en';
  final localeIndex = args.indexOf('--base-locale');
  if (localeIndex != -1 && localeIndex < args.length - 1) {
    baseLocale = args[localeIndex + 1];
  }

  final keyIsBaseText = args.contains('--key-is-base-text');
  final removeObsoleteKeys = args.contains('--remove-obsolete');

  addI18nKeysFromDir(
    sourceDir,
    translationsDir: translationsDir,
    baseLocale: baseLocale,
    keyIsBaseText: keyIsBaseText,
    removeObsoleteKeys: removeObsoleteKeys,
  );
}
