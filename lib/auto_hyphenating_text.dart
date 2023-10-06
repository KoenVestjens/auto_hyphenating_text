import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:hyphenator/hyphenator.dart';

enum AutoHyphenatingTextStyles {
  bold,
  code,
  link,
}

extension AutoHyphenatingTextStylesExtension on AutoHyphenatingTextStyles {
  String get markdown {
    switch (this) {
      case AutoHyphenatingTextStyles.bold:
        return '**';
      case AutoHyphenatingTextStyles.code:
        return '`';
      case AutoHyphenatingTextStyles.link:
        return '](';
      default:
        return '';
    }
  }
}

const String autoHyphenatingTextStyleLinkEnd = ')';
const String autoHyphenatingTextStyleLinkStart = '[';

Map<String, ResourceLoader> globalLoaders = {};

/// Inits the default global hyphenation loader. If this is omitted a custom hyphenation loader must be provided.
Future<void> initHyphenationWithLanguages(
    Map<String, DefaultResourceLoaderLanguage> languages) async {
  // globalLoader = await DefaultResourceLoader.load(language);

  languages.forEach((key, value) async {
    globalLoaders[key] = await DefaultResourceLoader.load(value);
  });
}

/// A replacement for the default text object which supports hyphenation.
class AutoHyphenatingText extends StatelessWidget {
  const AutoHyphenatingText(
    this.text, {
    this.shouldHyphenate,
    this.language = 'en',
    this.variables = const {},
    this.ignoreWords = const [],
    this.textStyles = const {},
    this.onTapLink,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.selectionColor,
    this.hyphenationCharacter = '‐',
    this.selectable = false,
    super.key,
  });

  final String text;
  final String language;
  final Map<String, String> variables;
  final List<String> ignoreWords;
  final Map<AutoHyphenatingTextStyles, TextStyle> textStyles;
  final Function(String?)? onTapLink;

  /// A function to tell us if we should apply hyphenation. If not given we will always hyphenate if possible.
  final bool Function(double totalLineWidth, double lineWidthAlreadyUsed,
      double currentWordWidth)? shouldHyphenate;

  final String hyphenationCharacter;

  final TextStyle? style;
  final TextAlign? textAlign;
  final StrutStyle? strutStyle;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final Color? selectionColor;
  final bool selectable;

  String mergeSyllablesFront(
      List<String> syllables, int indicesToMergeInclusive,
      {required bool allowHyphen}) {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i <= indicesToMergeInclusive; i++) {
      buffer.write(syllables[i]);
    }

    // Only write the hyphen if the character is not punctuation
    String returnString = buffer.toString();
    if (allowHyphen &&
        !RegExp('\\p{P}', unicode: true)
            .hasMatch(returnString[returnString.length - 1])) {
      return '$returnString$hyphenationCharacter';
    }

    return returnString;
  }

  String mergeSyllablesBack(
      List<String> syllables, int indicesToMergeInclusive) {
    StringBuffer buffer = StringBuffer();

    for (int i = indicesToMergeInclusive + 1; i < syllables.length; i++) {
      buffer.write(syllables[i]);
    }

    return buffer.toString();
  }

  int? effectiveMaxLines() =>
      overflow == TextOverflow.ellipsis && maxLines == null ? 1 : maxLines;

  bool allowHyphenation(int lines) =>
      overflow != TextOverflow.ellipsis || lines + 1 != effectiveMaxLines();

  @override
  Widget build(BuildContext context) {
    // This is used as a holder for the links
    Map<String, String> _links = {};

    double getTextWidth(String text, TextStyle? style, TextDirection? direction,
        double? scaleFactor) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaleFactor: scaleFactor ?? MediaQuery.of(context).textScaleFactor,
        maxLines: 1,
        textDirection: direction ?? Directionality.of(context),
      )..layout();
      return textPainter.size.width;
    }

    double getTextHeight(String text, TextStyle? style,
        TextDirection? direction, double? scaleFactor) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaleFactor: scaleFactor ?? MediaQuery.of(context).textScaleFactor,
        maxLines: 1,
        textDirection: direction ?? Directionality.of(context),
      )..layout();
      return textPainter.size.height;
    }

    int? getLastSyllableIndex(List<String> syllables, double availableSpace,
        TextStyle? effectiveTextStyle, int lines) {
      if (getTextWidth(
              mergeSyllablesFront(syllables, 0,
                  allowHyphen: allowHyphenation(lines)),
              effectiveTextStyle,
              textDirection,
              textScaleFactor) >
          availableSpace) {
        return null;
      }

      int lowerBound = 0;
      int upperBound = syllables.length;

      while (lowerBound != upperBound - 1) {
        int testIndex = ((lowerBound + upperBound) * 0.5).floor();

        if (getTextWidth(
                mergeSyllablesFront(syllables, testIndex,
                    allowHyphen: allowHyphenation(lines)),
                effectiveTextStyle,
                textDirection,
                textScaleFactor) >
            availableSpace) {
          upperBound = testIndex;
        } else {
          lowerBound = testIndex;
        }
      }

      return lowerBound;
    }

    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    // if (MediaQuery.boldTextOf(context)) {
    //   effectiveTextStyle = effectiveTextStyle!
    //       .merge(const TextStyle(fontWeight: FontWeight.bold));
    // }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      // Replace variables and split text into words
      List<String> words = replaceVariables(text).split(' ');
      List<TextSpan> texts = <TextSpan>[];

      assert(globalLoaders.isNotEmpty,
          'AutoHyphenatingText not initialized! Remember to call initHyphenation().');

      final Hyphenator hyphenator = Hyphenator(
        resource: globalLoaders[language] ?? globalLoaders['en']!,
        hyphenateSymbol: '_',
      );

      double singleSpaceWidth =
          getTextWidth(' ', effectiveTextStyle, textDirection, textScaleFactor);
      double currentLineSpaceUsed = 0;
      int lines = 0;

      double endBuffer = style?.overflow == TextOverflow.ellipsis
          ? getTextWidth('…', style, textDirection, textScaleFactor)
          : 0;

      for (int i = 0; i < words.length; i++) {
        double wordWidth = getTextWidth(
            words[i], effectiveTextStyle, textDirection, textScaleFactor);

        if (currentLineSpaceUsed + wordWidth <
            constraints.maxWidth - endBuffer) {
          // TODO: Duplicate
          if (hasMarkdownLink(words[i])) {
            Map<String, String> urlLink = getLink(words[i]);

            // Create internal link markdown
            String text = '__${urlLink['text']!}__';

            _links[text] = urlLink['url']!;

            texts.add(
              TextSpan(
                text: text,
              ),
            );
            // Inser a space so that the next word is not merged with the link
            words.insert(i + 1, '');
            continue;
          } else {
            texts.add(TextSpan(text: words[i]));
          }

          currentLineSpaceUsed += wordWidth;
        } else {
          final List<String> syllables = words[i].length == 1
              ? <String>[words[i]]
              : hyphenator.hyphenateWordToList(words[i]);
          final int? syllableToUse = words[i].length == 1
              ? null
              : getLastSyllableIndex(
                  syllables,
                  constraints.maxWidth - currentLineSpaceUsed,
                  effectiveTextStyle,
                  lines);

          if (syllableToUse == null ||
              (shouldHyphenate != null &&
                  !shouldHyphenate!(
                      constraints.maxWidth, currentLineSpaceUsed, wordWidth))) {
            if (currentLineSpaceUsed == 0) {
              texts.add(TextSpan(text: words[i]));
              currentLineSpaceUsed += wordWidth;
            } else {
              i--;
              if (texts.last == const TextSpan(text: ' ')) {
                texts.removeLast();
              }
              currentLineSpaceUsed = 0;
              lines++;
              if (effectiveMaxLines() != null &&
                  lines >= effectiveMaxLines()!) {
                if (overflow == TextOverflow.ellipsis) {
                  texts.add(const TextSpan(text: '…'));
                }
                break;
              }
              texts.add(const TextSpan(text: '\n'));
            }
            continue;
          } else {
            // Ignore variables
            bool ignore = false;
            for (String ignoreWord in ignoreWords) {
              if (words[i].contains(ignoreWord)) {
                ignore = true;
              }
            }

            // Ignore markdown words, TODO: for links this is not working properly
            if (hasMarkdownBold(words[i]) || hasMarkdownCode(words[i])) {
              ignore = true;
            }

            // TODO: Duplicate
            if (hasMarkdownLink(words[i])) {
              Map<String, String> urlLink = getLink(words[i]);

              // Create internal link markdown
              String text = '__${urlLink['text']!}__';

              _links[text] = urlLink['url']!;

              texts.add(
                TextSpan(
                  text: text,
                ),
              );
              // Inser a space so that the next word is not merged with the link
              words.insert(i + 1, '');
              continue;
            }

            if (ignore) {
              texts.add(
                TextSpan(
                  text: syllables.join(),
                ),
              );
              continue;
            } else {
              texts.add(TextSpan(
                  text: mergeSyllablesFront(syllables, syllableToUse,
                      allowHyphen: allowHyphenation(lines))));
              words.insert(i + 1, mergeSyllablesBack(syllables, syllableToUse));
            }

            currentLineSpaceUsed = 0;
            lines++;
            if (effectiveMaxLines() != null && lines >= effectiveMaxLines()!) {
              if (overflow == TextOverflow.ellipsis) {
                texts.add(const TextSpan(text: '…'));
              }
              break;
            }
            texts.add(const TextSpan(text: '\n'));
            continue;
          }
        }

        if (i != words.length - 1) {
          if (currentLineSpaceUsed + singleSpaceWidth < constraints.maxWidth) {
            texts.add(const TextSpan(text: ' '));
            currentLineSpaceUsed += singleSpaceWidth;
          } else {
            if (texts.last == const TextSpan(text: ' ')) {
              texts.removeLast();
            }
            currentLineSpaceUsed = 0;
            lines++;
            if (effectiveMaxLines() != null && lines >= effectiveMaxLines()!) {
              if (overflow == TextOverflow.ellipsis) {
                texts.add(const TextSpan(text: '…'));
              }
              break;
            }
            texts.add(const TextSpan(text: '\n'));
          }
        }
      }

      for (int i = 0; i < texts.length; i++) {
        String str = texts[i].text!;

        // Bold
        if (hasMarkdownBold(str)) {
          texts[i] = TextSpan(
            text: removeMarkdown(texts[i].text!),
            style: textStyles[AutoHyphenatingTextStyles.bold] ?? style!,
          );
          continue;
        }

        // Code
        if (hasMarkdownCode(str)) {
          texts[i] = TextSpan(
            text: removeMarkdown(str),
            style: textStyles[AutoHyphenatingTextStyles.code] ?? style!,
          );
          continue;
        }

        // Link
        if (_links.containsKey(texts[i].text!)) {
          final text = removeMarkdown(texts[i].text!);
          final link = _links[texts[i].text!]!;

          texts[i] = TextSpan(
            text: text,
            style: textStyles[AutoHyphenatingTextStyles.link] ?? style!,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onTapLink != null) {
                  onTapLink!(link);
                }
              },
          );
          continue;
        }
        // if (hasMarkdownLink(str)) {
        //   Map<String, String> urlLink = getLink(str);
        //   texts[i] = TextSpan(
        //     text: urlLink['text'],
        //     style: textStyles[AutoHyphenatingTextStyles.link] ?? style!,
        //     recognizer: TapGestureRecognizer()
        //       ..onTap = () {
        //         if (onTapLink != null) {
        //           onTapLink!(urlLink['url']);
        //         }
        //       },
        //   );
        //   continue;
        // }

        texts[i] = TextSpan(
          text: str,
          style: style,
        );
      }

      print('maxHeight: ${constraints.maxHeight}');
      print('maxWidth: ${constraints.maxWidth}');
      print('minHeight: ${constraints.minHeight}');
      print('minWidth: ${constraints.minWidth}');

      Widget child = LayoutBuilder(
        builder: (context, constraints) {
          // Your RichText widget here
          Widget child = RichText(
            textDirection: textDirection,
            strutStyle: strutStyle,
            locale: locale,
            softWrap: softWrap ?? true,
            overflow: overflow ?? TextOverflow.clip,
            textScaleFactor:
                textScaleFactor ?? MediaQuery.of(context).textScaleFactor,
            textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
            selectionColor: selectionColor,
            textAlign: textAlign ?? TextAlign.start,
            text: TextSpan(
              style: effectiveTextStyle,
              children: texts,
            ),
          );

          return SizedBox(
            height: constraints.maxHeight,
            child: child,
          );
        },
      );

      return Semantics(
        textDirection: textDirection,
        label: semanticsLabel ?? text,
        child: ExcludeSemantics(
          child: child,
        ),
      );

      // return Container(
      //   width: double.infinity,
      //   height: 60, //constraints.maxHeight,
      //   color: Colors.yellow,
      //   child: Semantics(
      //     textDirection: textDirection,
      //     label: semanticsLabel ?? text,
      //     child: ExcludeSemantics(
      //       child: RichText(
      //         textDirection: textDirection,
      //         strutStyle: strutStyle,
      //         locale: locale,
      //         softWrap: softWrap ?? true,
      //         overflow: overflow ?? TextOverflow.clip,
      //         textScaleFactor:
      //             textScaleFactor ?? MediaQuery.of(context).textScaleFactor,
      //         textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
      //         selectionColor: selectionColor,
      //         textAlign: textAlign ?? TextAlign.start,
      //         text: TextSpan(
      //           style: effectiveTextStyle,
      //           children: texts,
      //         ),
      //       ),
      //     ),
      //   ),
      // );
    });
  }

  String replaceVariables(String text) {
    return variables.entries
        .fold(text, (prev, e) => prev.replaceAll(e.key, e.value));
  }

  String removeMarkdown(String text) {
    return text
        .replaceAll(AutoHyphenatingTextStyles.bold.markdown, '')
        .replaceAll(AutoHyphenatingTextStyles.code.markdown, '')
        // This is only internally used, so there is no AutoHyphenatingTextStyles for this markdown
        .replaceAll('__', '');
  }

  bool hasMarkdownBold(String str) {
    return str.startsWith(AutoHyphenatingTextStyles.bold.markdown) &&
        str.endsWith(AutoHyphenatingTextStyles.bold.markdown);
  }

  bool hasMarkdownCode(String str) {
    return str.startsWith(AutoHyphenatingTextStyles.code.markdown) &&
        str.endsWith(AutoHyphenatingTextStyles.code.markdown);
  }

  bool hasMarkdownLink(String str) {
    bool hasLink = str.startsWith(autoHyphenatingTextStyleLinkStart) &&
        str.endsWith(autoHyphenatingTextStyleLinkEnd) &&
        str.contains(AutoHyphenatingTextStyles.link.markdown);
    return hasLink;
  }

  Map<String, String> getLink(String str) {
    // Get text
    const startText = autoHyphenatingTextStyleLinkStart;
    String endText = AutoHyphenatingTextStyles.link.markdown;

    final startIndexText = str.indexOf(startText);
    final endIndexText =
        str.indexOf(endText, startIndexText + startText.length);

    final text = str.substring(startIndexText + startText.length, endIndexText);

    // Get url
    String startUrl = AutoHyphenatingTextStyles.link.markdown;
    const endUrl = autoHyphenatingTextStyleLinkEnd;

    final startIndexUrl = str.indexOf(startUrl);
    final endIndexUrl = str.indexOf(endUrl, startIndexUrl + startUrl.length);

    final url = str.substring(startIndexUrl + startUrl.length, endIndexUrl);

    return {'text': text, 'url': url};
  }
}
