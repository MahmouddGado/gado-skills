# Localization, RTL and theme

## l10n

- ARB files: `app_ar.arb` (template when the product is Arabic-first) and `app_en.arb`.
  Add every key to **both** files in the same change.
- Keys are `camelCase`, prefixed by feature: `tripsTitle`, `bookingSubmit`,
  `walletBalanceLabel`, `errorTripFull`.
- Use placeholders and ICU plurals, never string concatenation:

```json
"tripsSeatsLeft": "{count, plural, =0{لا توجد مقاعد} =1{مقعد واحد متبقٍ} =2{مقعدان متبقيان} few{{count} مقاعد متبقية} many{{count} مقعدًا متبقيًا} other{{count} مقعد متبقٍ}}",
"@tripsSeatsLeft": { "placeholders": { "count": { "type": "int" } } }
```

- Access through an extension so widgets stay short:

```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

- Regenerate with `flutter gen-l10n` (or on build with `generate: true`).
- Dates, numbers and money via `intl` formatters with the current locale; keep
  formatters in core (`MoneyFormatter.format(piastres, locale)`).
- Arabic numerals vs Western: follow product decision; keep it in one formatter.

## RTL-safe layout

| Avoid | Use |
| --- | --- |
| `EdgeInsets.only(left: 8)` | `EdgeInsetsDirectional.only(start: 8)` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `Positioned(left: 0)` | `PositionedDirectional(start: 0)` |
| `TextAlign.left` | `TextAlign.start` |
| `Icons.arrow_back` hard-coded | `BackButtonIcon()` / `Icons.adaptive.arrow_back` |
| `BorderRadius.only(topLeft:)` | `BorderRadiusDirectional.only(topStart:)` |

- Directional icons (arrows, chevrons) that must flip: wrap in
  `Directionality`-aware widgets or use `Transform.flip(flipX: isRtl)`.
- Phone numbers, plate numbers and codes inside Arabic text: wrap with
  `Directionality(textDirection: TextDirection.ltr, ...)` or Unicode LRM marks.
- Test both directions: widget tests pump with `locale: Locale('ar')` and
  `Locale('en')` for key screens.

## Theme

- All colours, spacing, radii, typography come from theme tokens in core.
  Never `Color(0xFF...)`, raw `SizedBox(height: 13)` or ad-hoc `TextStyle`
  in features.
- Expose custom tokens through a `ThemeExtension` so widgets read
  `context.colors.brandAccent` and dark mode works automatically:

```dart
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.brand, required this.accent, required this.success});

  final Color brand;
  final Color accent;
  final Color success;

  @override
  AppColors copyWith({Color? brand, Color? accent, Color? success}) => AppColors(
    brand: brand ?? this.brand,
    accent: accent ?? this.accent,
    success: success ?? this.success,
  );

  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          brand: Color.lerp(brand, other.brand, t)!,
          accent: Color.lerp(accent, other.accent, t)!,
          success: Color.lerp(success, other.success, t)!,
        );
}

extension ThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => TextTheme.of(this);
}
```

- Spacing: `AppSpace.s8`, `AppSpace.s16` constants; gaps with `SizedBox`
  constants or `spacing:` on `Row`/`Column`.
- Material 3 (`useMaterial3` default). Component themes (`FilledButtonThemeData`,
  `InputDecorationTheme`, `CardThemeData`) configured once in core.
- Fonts that support Arabic (e.g. Cairo) bundled as assets, not fetched at runtime.
