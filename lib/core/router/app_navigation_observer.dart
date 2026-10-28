import 'package:flutter/widgets.dart';

/// The active route's pop guards also protect it from reminder interruptions.
class AppNavigationObserver extends NavigatorObserver {
  final VoidCallback onChanged;
  Route<dynamic>? topRoute;
  AppNavigationObserver(this.onChanged);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    this.topRoute = topRoute;
    onChanged();
  }
}
