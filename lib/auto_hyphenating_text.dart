// ignore_for_file: must_be_immutable

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
class AutoHyphenatingText extends StatefulWidget {
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
    this.hyphenationCharacter = '–',
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

  @override
  State<AutoHyphenatingText> createState() => _AutoHyphenatingTextState();
}

class _AutoHyphenatingTextState extends State<AutoHyphenatingText> {
  int _lines = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('test');
      setState(() {});
    });
  }

  // This is used to calculate the height of the widget
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
      return '$returnString${widget.hyphenationCharacter}';
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
      widget.overflow == TextOverflow.ellipsis && widget.maxLines == null
          ? 1
          : widget.maxLines;

  bool allowHyphenation(int lines) =>
      widget.overflow != TextOverflow.ellipsis ||
      lines + 1 != effectiveMaxLines();

  @override
  Widget build(BuildContext context) {
    // This is used as a holder for the links
    Map<String, String> links = {};

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

    int? getLastSyllableIndex(List<String> syllables, double availableSpace,
        TextStyle? effectiveTextStyle, int lines) {
      if (getTextWidth(
              mergeSyllablesFront(syllables, 0,
                  allowHyphen: allowHyphenation(lines)),
              effectiveTextStyle,
              widget.textDirection,
              widget.textScaleFactor) >
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
                widget.textDirection,
                widget.textScaleFactor) >
            availableSpace) {
          upperBound = testIndex;
        } else {
          lowerBound = testIndex;
        }
      }

      return lowerBound;
    }

    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = widget.style;
    if (widget.style == null || widget.style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(widget.style);
    }
    // if (MediaQuery.boldTextOf(context)) {
    //   effectiveTextStyle = effectiveTextStyle!
    //       .merge(const TextStyle(fontWeight: FontWeight.bold));
    // }

    print(effectiveTextStyle!.fontSize!);

    return Container(
      height: effectiveTextStyle!.fontSize! * _lines,
      color: Colors.red,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Replace variables and split the text on space, dot and comma into words
          List<String> words =
              replaceVariables(widget.text).split(RegExp(r'[ ,.]'));
          List<TextSpan> texts = <TextSpan>[];

          assert(globalLoaders.isNotEmpty,
              'AutoHyphenatingText not initialized! Remember to call initHyphenation().');

          final Hyphenator hyphenator = Hyphenator(
            resource: globalLoaders[widget.language] ?? globalLoaders['en']!,
            hyphenateSymbol: '_',
          );

          double singleSpaceWidth = getTextWidth(' ', effectiveTextStyle,
              widget.textDirection, widget.textScaleFactor);

          double currentLineSpaceUsed = 0;
          int lines = 0;

          double endBuffer = widget.style?.overflow == TextOverflow.ellipsis
              ? getTextWidth('…', widget.style, widget.textDirection,
                  widget.textScaleFactor)
              : 0;

          for (int i = 0; i < words.length; i++) {
            double wordWidth = getTextWidth(words[i], effectiveTextStyle,
                widget.textDirection, widget.textScaleFactor);

            if (currentLineSpaceUsed + wordWidth <
                constraints.maxWidth - endBuffer) {
              // TODO: Duplicate
              if (hasMarkdownLink(words[i])) {
                Map<String, String> urlLink = getLink(words[i]);

                // Create internal link markdown
                String text = '__${urlLink['text']!}__';

                links[text] = urlLink['url']!;

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
                  (widget.shouldHyphenate != null &&
                      !widget.shouldHyphenate!(constraints.maxWidth,
                          currentLineSpaceUsed, wordWidth))) {
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
                    if (widget.overflow == TextOverflow.ellipsis) {
                      texts.add(const TextSpan(text: '…'));
                    }
                    break;
                  }
                  // testLines++;
                  texts.add(const TextSpan(text: '\n'));
                }
                continue;
              } else {
                // Ignore variables
                bool ignore = false;
                for (String ignoreWord in widget.ignoreWords) {
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

                  links[text] = urlLink['url']!;

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
                  words.insert(
                      i + 1, mergeSyllablesBack(syllables, syllableToUse));
                }

                currentLineSpaceUsed = 0;
                lines++;
                if (effectiveMaxLines() != null &&
                    lines >= effectiveMaxLines()!) {
                  if (widget.overflow == TextOverflow.ellipsis) {
                    texts.add(const TextSpan(text: '…'));
                  }
                  break;
                }
                // testLines++;
                texts.add(const TextSpan(text: '\n'));
                continue;
              }
            }

            if (i != words.length - 1) {
              if (currentLineSpaceUsed + singleSpaceWidth <
                  constraints.maxWidth) {
                texts.add(const TextSpan(text: ' '));
                currentLineSpaceUsed += singleSpaceWidth;
              } else {
                if (texts.last == const TextSpan(text: ' ')) {
                  texts.removeLast();
                }
                currentLineSpaceUsed = 0;
                lines++;
                if (effectiveMaxLines() != null &&
                    lines >= effectiveMaxLines()!) {
                  if (widget.overflow == TextOverflow.ellipsis) {
                    texts.add(const TextSpan(text: '…'));
                  }
                  break;
                }
                // testLines++;
                texts.add(const TextSpan(text: '\n'));
              }
            }
          }

          // Determine if the are two markdown words after each other with no space between them. If there is no space between them
          // and no new line between them, then add a space between them.
          List<TextSpan> newTexts = [];
          for (int i = 0; i < texts.length; i++) {
            newTexts.add(texts[i]);

            String text = texts[i].text!;
            String nextText = '';
            if (i + 1 < texts.length) {
              nextText = texts[i + 1].text!;
            }

            if ((hasMarkdownBold(text) && hasMarkdownBold(nextText)) ||
                (hasMarkdownCode(text) && hasMarkdownCode(nextText)) ||
                (hasMarkdownLink(text) && hasMarkdownLink(nextText))) {
              newTexts.add(TextSpan(text: ' '));
              continue;
            }

            // Check if the next text is no markdown and no new line or space, then add space
            if ((hasMarkdownBold(text) ||
                    hasMarkdownCode(text) ||
                    hasMarkdownLink(text)) &&
                (!nextText.startsWith('__') &&
                    !nextText.startsWith('\n') &&
                    !nextText.startsWith(' '))) {
              newTexts.add(TextSpan(text: ' '));
              continue;
            }
          }

          // Remove markdown
          for (int i = 0; i < newTexts.length; i++) {
            String str = newTexts[i].text!;

            // Bold
            if (hasMarkdownBold(str)) {
              newTexts[i] = TextSpan(
                text: removeMarkdown(newTexts, newTexts[i].text!),
                style: widget.textStyles[AutoHyphenatingTextStyles.bold] ??
                    widget.style!,
              );
              continue;
            }

            // Code
            if (hasMarkdownCode(str)) {
              newTexts[i] = TextSpan(
                text: removeMarkdown(newTexts, str),
                style: widget.textStyles[AutoHyphenatingTextStyles.code] ??
                    widget.style!,
              );
              continue;
            }

            // Link
            if (links.containsKey(newTexts[i].text!)) {
              final text = removeMarkdown(newTexts, newTexts[i].text!);
              final link = links[newTexts[i].text!]!;

              newTexts[i] = TextSpan(
                text: text,
                style: widget.textStyles[AutoHyphenatingTextStyles.link] ??
                    widget.style!,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    if (widget.onTapLink != null) {
                      widget.onTapLink!(link);
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

            newTexts[i] = TextSpan(
              text: str,
              style: widget.style,
            );
          }

          _lines = lines + 1;

          return Semantics(
            textDirection: widget.textDirection,
            label: widget.semanticsLabel ?? widget.text,
            child: ExcludeSemantics(
              child: RichText(
                textDirection: widget.textDirection,
                strutStyle: widget.strutStyle,
                locale: widget.locale,
                softWrap: widget.softWrap ?? true,
                textScaleFactor: widget.textScaleFactor ??
                    MediaQuery.of(context).textScaleFactor,
                textWidthBasis: widget.textWidthBasis ?? TextWidthBasis.parent,
                selectionColor: widget.selectionColor,
                textAlign: widget.textAlign ?? TextAlign.start,
                text: TextSpan(
                  style: effectiveTextStyle,
                  children: newTexts,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String replaceVariables(String text) {
    return widget.variables.entries
        .fold(text, (prev, e) => prev.replaceAll(e.key, e.value));
  }

  String removeMarkdown(List<TextSpan> texts, String text) {
    return text
        .replaceAll(AutoHyphenatingTextStyles.bold.markdown, '')
        .replaceAll(AutoHyphenatingTextStyles.code.markdown, '')
        // This is only internally used, so there is no AutoHyphenatingTextStyles for this markdown
        .replaceAll('__', '');
  }

  bool hasMarkdownBold(String str) {
    return str.startsWith(AutoHyphenatingTextStyles.bold.markdown) ||
        str.endsWith(AutoHyphenatingTextStyles.bold.markdown);
  }

  bool hasMarkdownCode(String str) {
    return str.startsWith(AutoHyphenatingTextStyles.code.markdown) ||
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
