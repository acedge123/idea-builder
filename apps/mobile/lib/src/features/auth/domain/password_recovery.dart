/// The existing website owns email requests and recovery tokens in one browser.
/// Native opens the existing browser recovery form through its validated entry mode.
/// No email, password or token is placed in a URL.
abstract final class PasswordRecovery {
  static final pageUri = Uri.parse('https://www.musicdna.fm/auth?mode=forgot');
}
