import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../config.dart';
import 'settings_service.dart';

/// Google account + Drive authorization.
///
/// SLife only asks for the `drive.file` scope: it can see and manage the
/// files it creates in your Drive, and nothing else.
class AuthService extends ChangeNotifier {
  AuthService(this._settings);

  static const scopes = <String>[drive.DriveApi.driveFileScope];

  final SettingsService _settings;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  GoogleSignInAccount? _user;
  bool _initialized = false;
  bool _busy = false;
  bool _needsReauth = false;
  String? _error;
  String? _lastToken;

  GoogleSignInAccount? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isConfigured => AppConfig.isDriveConfigured;
  bool get busy => _busy;

  /// Signed in, but Drive access must be granted again interactively.
  bool get needsReauth => _needsReauth;
  String? get error => _error;

  Future<void> init() async {
    if (_initialized || !isConfigured) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: AppConfig.googleWebClientId.isEmpty
            ? null
            : AppConfig.googleWebClientId,
      );
      _initialized = true;
      _sub = GoogleSignIn.instance.authenticationEvents.listen(
        _onAuthEvent,
        onError: (Object e) {
          _error = describeError(e);
          notifyListeners();
        },
      );
      if (_settings.driveLinked) {
        final account = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        if (account != null) _user = account;
      }
    } catch (e) {
      debugPrint('SLife: Google Sign-In init failed: $e');
      _error = describeError(e);
    }
    notifyListeners();
  }

  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _user = event.user;
      case GoogleSignInAuthenticationEventSignOut():
        _user = null;
    }
    notifyListeners();
  }

  /// Interactive sign-in followed by the Drive permission prompt.
  Future<bool> connect() async {
    if (!isConfigured) {
      _error = 'Google Drive is not configured yet. Add your OAuth client ID (see README).';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (!_initialized) await init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      _user = account;
      await account.authorizationClient.authorizeScopes(scopes);
      _needsReauth = false;
      await _settings.setDriveLinked(true);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _error = describeError(e);
      }
      return false;
    } catch (e) {
      _error = describeError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Asks the user to grant Drive access again (e.g. after it was revoked).
  Future<bool> reauthorize() async {
    final user = _user;
    if (user == null) return connect();
    try {
      await user.authorizationClient.authorizeScopes(scopes);
      _needsReauth = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = describeError(e);
      notifyListeners();
      return false;
    }
  }

  /// An HTTP client authorized for Drive, or null when the user has to grant
  /// access interactively first.
  Future<http.Client?> driveClient({bool interactive = false}) async {
    final user = _user;
    if (user == null) return null;
    final headers = await user.authorizationClient.authorizationHeaders(
      scopes,
      promptIfNecessary: interactive,
    );
    if (headers == null) {
      _needsReauth = true;
      notifyListeners();
      return null;
    }
    _lastToken = headers['Authorization']?.replaceFirst('Bearer ', '');
    if (_needsReauth) {
      _needsReauth = false;
      notifyListeners();
    }
    return _AuthHeadersClient(headers);
  }

  /// Drops a rejected access token so the next request fetches a fresh one.
  Future<void> invalidateToken() async {
    final token = _lastToken;
    if (token == null) return;
    _lastToken = null;
    try {
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    _user = null;
    _needsReauth = false;
    await _settings.setDriveLinked(false);
    await _settings.setDriveRootId(null);
    notifyListeners();
  }

  static String describeError(Object e) {
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is not configured correctly. Check the OAuth client IDs, '
              'package name and SHA-1 in Google Cloud.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google Play services could not complete sign-in on this device.',
        GoogleSignInExceptionCode.canceled => 'Sign-in was cancelled.',
        GoogleSignInExceptionCode.interrupted =>
          'Sign-in was interrupted. Please try again.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Sign-in UI is not available right now.',
        _ => e.description ?? 'Google sign-in failed.',
      };
    }
    return e.toString();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _AuthHeadersClient extends http.BaseClient {
  _AuthHeadersClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
