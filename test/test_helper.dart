import 'package:flutter/material.dart';

import 'package:el_nemr_language/l10n/app_localizations.dart';

/// Wraps a widget in a MaterialApp with the app's localization delegates so
/// that `AppLocalizations.of(context)` works in widget tests.
MaterialApp localizedApp(Widget child, {Key? key, Map<String, String>? builderOverrides}) {
  return MaterialApp(
    key: key,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
