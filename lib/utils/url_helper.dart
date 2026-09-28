import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';
import 'app_snackbar.dart';

const _allowedSchemes = {'http', 'https', 'mailto'};

/// Opens [url] in an external app.
///
/// `launchUrl` is called directly instead of gating on `canLaunchUrl`, which
/// returns false on Android 11+ unless the scheme is declared in `<queries>`.
/// Only web and mail links are opened, since URLs come from user content.
Future<bool> openExternalUrl(String url) async {
  var uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (!uri.hasScheme) uri = Uri.tryParse('https://${url.trim()}');
  if (uri == null || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
    AppLogger.warning('Blocked link with unsupported scheme: $url');
    return false;
  }

  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (e) {
    AppLogger.error('Could not launch $url', e);
  }
  AppSnackbar.error('Could not open link');
  return false;
}
