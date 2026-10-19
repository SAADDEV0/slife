import 'dart:io';

/// Google Drive configuration for SLife.
///
/// Drive sync needs OAuth client IDs from your own Google Cloud project.
/// See README.md → "Connect Google Drive" for a step-by-step guide.
///
/// Either paste the IDs into the `defaultValue`s below, or pass them at
/// build time:
///
///   flutter run --dart-define=SLIFE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com
class AppConfig {
  AppConfig._();

  /// OAuth client ID of type **Web application**.
  ///
  /// Required on Android, where it is passed to Google Sign-In as the
  /// `serverClientId`.
  static const String googleWebClientId = String.fromEnvironment(
    'SLIFE_WEB_CLIENT_ID',
    // "SLife server" client in Google Cloud project slife-511622.
    defaultValue: '174216560420-kmasu7ujop9si1bf8co8i5g3lkl32gom.apps.googleusercontent.com',
  );

  /// OAuth client ID of type **iOS**. Only needed for iOS builds (also add
  /// its reversed form as a URL scheme in `ios/Runner/Info.plist`).
  static const String googleIosClientId = String.fromEnvironment(
    'SLIFE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Name of the folder SLife creates at the root of your Google Drive.
  static const String driveRootFolder = 'SLife';

  /// Whether Google Drive sign-in has been configured for this platform.
  static bool get isDriveConfigured {
    if (Platform.isIOS) return googleIosClientId.isNotEmpty;
    return googleWebClientId.isNotEmpty;
  }
}
