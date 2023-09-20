`AutoHyphenatingText` is a drop in replacement for the default `Text` that supports autohyphenating text.

![Demo](https://media4.giphy.com/media/iAfRO9amZZNe8MwFG1/giphy.gif)

## Usage

This package needs to be initialized using the following, also when the language is changed (for example in `reloadLanguageWith()` used in most of our apps):

```dart
await initHyphenationWithLanguages({
      'en': DefaultResourceLoaderLanguage.enUs,
      'de': DefaultResourceLoaderLanguage.de1996,
      'nl': DefaultResourceLoaderLanguage.nl
    });
```

This will load the hyphenation algorithm. You can skip this step if you manually initialized the hyphenation algorithm yourself.

```dart
AutoHyphenatingText('**%pp%** & %count% en `%ap%` herinneringen discover profile ingesteld. [discover](https://www.google.com) pro. [profile](profile-link) test',
                    language: AppLanguage.current!,
                    variables: variables,
                    ignoreWords: variables.values.toList(),
                    textStyles: {
                        AutoHyphenatingTextStyles.bold: textStyle.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                        ),
                        AutoHyphenatingTextStyles.code: textStyle.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                        ),
                        AutoHyphenatingTextStyles.link: textStyle.copyWith(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                        ),
                    },
                    style: textStyle,
                    textAlign: TextAlign.center,
                    onTapLink: (href) {
                        if (href == null) return;
                            print(href);
                        },
                    )
```
