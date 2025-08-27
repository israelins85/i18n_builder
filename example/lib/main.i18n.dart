import 'package:i18n_extension/i18n_extension.dart';

extension MyTranslations on String {
  static final _t = Translations.byFile('en-US', dir: 'assets/translations');

  static Future<void> load() => _t.load();

  String get i18n => localize(this, _t);
  String plural(Object? value) => localizePlural(value, this, _t);
}
