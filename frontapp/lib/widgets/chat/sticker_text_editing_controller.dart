import 'package:flutter/material.dart';
import '../../utils/emotion_asset_helper.dart';

class StickerTextEditingController extends TextEditingController {
  @override
  set value(TextEditingValue newValue) {
    final oldText = value.text;
    final newText = newValue.text;
    final newSelection = newValue.selection;

    // 1. Handle Atomic Deletion
    if (oldText.length > newText.length &&
        newSelection.isValid &&
        newSelection.isCollapsed) {
      final index = newSelection.baseOffset;
      // Check if the deleted character (which was at 'index' in oldText) was ')'
      if (index < oldText.length && oldText[index] == ')') {
        final prefixToCheck = oldText.substring(0, index + 1);
        final match = RegExp(r'\([A-Z]+\)$').firstMatch(prefixToCheck);
        if (match != null) {
          // Found a sticker pattern ending at the deletion point.
          // Delete the whole sticker.
          final start = match.start;
          final end = match.end; // This should be index + 1

          final refinedText =
              oldText.substring(0, start) + oldText.substring(end);
          final refinedSelection = TextSelection.collapsed(offset: start);

          super.value = TextEditingValue(
            text: refinedText,
            selection: refinedSelection,
            composing: TextRange.empty,
          );
          return;
        }
      }
    }

    // 2. Handle Atomic Navigation (Prevent cursor inside sticker)
    if (newText.length == oldText.length &&
        newSelection.isValid &&
        newSelection.isCollapsed) {
      final cursor = newSelection.baseOffset;
      final oldCursor =
          value.selection.isValid ? value.selection.baseOffset : -1;
      final matches = RegExp(r'(\([A-Z]+\))').allMatches(newText);

      for (final m in matches) {
        if (cursor > m.start && cursor < m.end) {
          // Cursor landed inside a sticker.
          int targetOffset;

          if (oldCursor != -1) {
            // Determine direction based on previous position
            if (cursor > oldCursor) {
              // Moving Right -> Jump to End
              targetOffset = m.end;
            } else if (cursor < oldCursor) {
              // Moving Left -> Jump to Start
              targetOffset = m.start;
            } else {
              // No horizontal movement (e.g. tap) -> Jump to End
              // Jumping to Start is confusing as users typically want to append.
              targetOffset = m.end;
            }
          } else {
            // Fallback
            targetOffset = m.end;
          }

          super.value = newValue.copyWith(
            selection: TextSelection.collapsed(offset: targetOffset),
          );
          return;
        }
      }
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    final text = value.text;

    // Regex to match (EMOTION) pattern
    final regex = RegExp(r'(\([A-Z]+\))');

    // Split text by regex
    text.splitMapJoin(
      regex,
      onMatch: (Match match) {
        final code = match.group(0)!; // e.g., (JOY)
        final emotionKey = code.substring(1, code.length - 1); // JOY

        // 1. Add WidgetSpan for the FIRST character
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Image.asset(
                EmotionAssetHelper.getAssetPath(emotionKey),
                width: 20, // Small size to match text
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to text if asset not found
                  return Text(code, style: style);
                },
              ),
            ),
          ),
        );

        // 2. Add invisible text for the REMAINING characters
        // This ensures the TextSpan tree length matches the controller text length.
        if (code.length > 1) {
          children.add(
            TextSpan(
              text: code.substring(1),
              style: const TextStyle(
                fontSize: 0,
                color: Colors.transparent,
                height: 0,
              ),
            ),
          );
        }

        return code;
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          children.add(TextSpan(text: nonMatch, style: style));
        }
        return nonMatch;
      },
    );

    return TextSpan(style: style, children: children);
  }
}
