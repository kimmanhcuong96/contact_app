import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/theme/app_theme.dart';

void main() {
  test('NexBook themes keep brand roles distinct and text accessible', () {
    for (final theme in [NexBookTheme.light, NexBookTheme.dark]) {
      final colors = theme.colorScheme;
      expect(colors.primary, isNot(colors.secondary));
      expect(colors.secondary, isNot(colors.tertiary));
      expect(_contrast(colors.primary, colors.onPrimary), greaterThan(4.5));
      expect(_contrast(colors.surface, colors.onSurface), greaterThan(4.5));
      expect(theme.cardTheme.elevation, 0);
      expect(theme.navigationBarTheme.height, 70);
    }
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
