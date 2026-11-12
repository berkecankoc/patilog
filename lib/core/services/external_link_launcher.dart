abstract interface class ExternalLinkLauncher {
  /// Opens [uri] in another app, such as the browser.
  ///
  /// Returns false when no app could open it.
  Future<bool> open(Uri uri);
}
