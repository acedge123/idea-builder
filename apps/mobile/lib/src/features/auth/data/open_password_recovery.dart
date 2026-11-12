import 'package:url_launcher/url_launcher.dart';

Future<bool> openPasswordRecovery(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
