# i18n_builder

A Dart builder that automatically updates i18n translation files.

## Features

- Automatically detects .i18n keys in your Dart files
- Updates translation JSON files
- Maintains existing translations
- Removes obsolete keys
- based on format of translations in [i18n_extension](https://pub.dev/packages/i18n_extension)

## Usage

1. Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
    i18n_builder: ^1.1.1
```

2. (Optional) Add to your `build.yaml` or create a `i18n_builder.yaml` file:

```yaml
builders:
    i18n_builder:
        enabled: true
        base_locale: en-US # default
        translations_dir: assets/translations # default
        key_is_base_text: true # default - if true, the key will be set to the base locale text
```

## Suggestions

- You can use the [BabelEdit](https://www.codeandweb.com/babeledit) to make easy translate your files.
