import 'package:patilog/core/services/external_link_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

final class UrlExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlExternalLinkLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      // The browser loads the page; Patilog itself stays offline.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
