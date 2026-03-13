import 'dart:convert';
import 'dart:io';

import 'package:i18n_builder/src/functions.dart';
import 'package:test/test.dart';

void main() {
  group('persistI18nKeys', () {
    test('keeps distinct keys that differ only by case', () {
      final tempDir = Directory.systemTemp.createTempSync('i18n_builder_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final file = File('${tempDir.path}/en-US.json')..writeAsStringSync('{}');

      persistI18nKeys(file, {
        '@@locale': 'en-US',
        'Tank': 'Tank',
        'tank': 'tank',
      });

      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(saved['@@locale'], 'en-US');
      expect(saved['Tank'], 'Tank');
      expect(saved['tank'], 'tank');
      expect(saved.keys.where((key) => key.toLowerCase() == 'tank'), hasLength(2));
    });
  });
}
