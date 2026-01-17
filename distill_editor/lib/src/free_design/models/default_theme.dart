import 'theme_document.dart';
import 'token_schema.dart';

/// Default token schema for new documents.
///
/// Provides a standard set of design tokens for:
/// - Colors: primary, secondary, surface, text variants, semantic colors
/// - Spacing: xs through xxl (4px to 48px)
/// - Radius: none through full (0 to 9999)
/// - Typography: display, title, body, caption presets
const defaultTokenSchema = TokenSchema(
  color: {
    'primary': '#007AFF',
    'secondary': '#5856D6',
    'background': '#FFFFFF',
    'surface': '#F5F5F5',
    'text': {
      'primary': '#000000',
      'secondary': '#666666',
      'disabled': '#999999',
    },
    'error': '#FF3B30',
    'success': '#34C759',
  },
  spacing: {
    'none': 0,
    'xs': 4,
    'sm': 8,
    'md': 16,
    'lg': 24,
    'xl': 32,
    'xxl': 48,
  },
  radius: {
    'none': 0,
    'sm': 4,
    'md': 8,
    'lg': 12,
    'xl': 16,
    'full': 9999,
  },
  typography: {
    'display': TypographyToken(size: 32, weight: 700, lineHeight: 1.2),
    'title': TypographyToken(size: 24, weight: 600, lineHeight: 1.3),
    'body': TypographyToken(size: 16, weight: 400, lineHeight: 1.5),
    'caption': TypographyToken(size: 12, weight: 400, lineHeight: 1.4),
  },
);

/// Default theme document wrapping the token schema.
///
/// This is the theme applied to new documents and documents without
/// an explicit theme field.
const defaultTheme = ThemeDocument(
  id: 'default',
  name: 'Starter',
  tokens: defaultTokenSchema,
);
