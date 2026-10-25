import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis_auth;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: (map['displayName'] as String?) ?? map['email'] as String,
        photoUrl: map['photoUrl'] as String?,
      );
}

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const String driveScope = drive.DriveApi.driveAppdataScope;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [driveScope],
  );

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  gapis_auth.AuthClient? _desktopAuthClient;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Initializes auth state and attempts silent sign-in.
  Future<AuthUser?> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserJson = prefs.getString('cached_auth_user');

      if (_isDesktop) {
        // Desktop: load cached desktop credentials if available
        final credsJson = prefs.getString('desktop_oauth_credentials');
        if (credsJson != null) {
          try {
            final map = jsonDecode(credsJson) as Map<String, dynamic>;
            final accessCredentials = gapis_auth.AccessCredentials(
              gapis_auth.AccessToken(
                map['type'] as String? ?? 'Bearer',
                map['data'] as String,
                DateTime.parse(map['expiry'] as String),
              ),
              map['refreshToken'] as String?,
              (map['scopes'] as List).cast<String>(),
              idToken: map['idToken'] as String?,
            );

            final clientIdStr = prefs.getString('desktop_oauth_client_id') ?? '';
            final clientSecretStr = prefs.getString('desktop_oauth_client_secret') ?? '';

            if (clientIdStr.isNotEmpty) {
              final clientId = gapis_auth.ClientId(clientIdStr, clientSecretStr.isEmpty ? null : clientSecretStr);
              _desktopAuthClient = auth_io.autoRefreshingClient(clientId, accessCredentials, http.Client());
              if (cachedUserJson != null) {
                _currentUser = AuthUser.fromMap(jsonDecode(cachedUserJson) as Map<String, dynamic>);
                return _currentUser;
              }
            }
          } catch (e) {
            debugPrint('[AuthService] Desktop credentials restore error: $e');
          }
        }
        return null;
      }

      // Mobile / Web
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = AuthUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName ?? account.email,
          photoUrl: account.photoUrl,
        );
        await _persistUser(_currentUser!);
        return _currentUser;
      }

      // If silent sign in returned null but cached user exists, keep it until sign in
      if (cachedUserJson != null) {
        _currentUser = AuthUser.fromMap(jsonDecode(cachedUserJson) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[AuthService] Silent sign in error: $e');
    }
    return _currentUser;
  }

  /// Interactive sign-in.
  Future<AuthUser?> signIn({
    String? desktopClientId,
    String? desktopClientSecret,
  }) async {
    if (_isDesktop) {
      return _signInDesktop(
        clientIdStr: desktopClientId,
        clientSecretStr: desktopClientSecret,
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      _currentUser = AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? account.email,
        photoUrl: account.photoUrl,
      );
      await _persistUser(_currentUser!);
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] Interactive sign in error: $e');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      if (!_isDesktop) {
        await _googleSignIn.signOut();
      } else {
        _desktopAuthClient?.close();
        _desktopAuthClient = null;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_auth_user');
      await prefs.remove('desktop_oauth_credentials');
      _currentUser = null;
    } catch (e) {
      debugPrint('[AuthService] Sign out error: $e');
    }
  }

  /// Disconnect current account and allow selecting another one.
  Future<AuthUser?> switchAccount({
    String? desktopClientId,
    String? desktopClientSecret,
  }) async {
    await signOut();
    if (!_isDesktop) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
    }
    return signIn(
      desktopClientId: desktopClientId,
      desktopClientSecret: desktopClientSecret,
    );
  }

  /// Returns an authenticated HTTP client for Google APIs (Drive v3).
  Future<http.Client?> getAuthenticatedClient() async {
    if (_isDesktop) {
      return _desktopAuthClient;
    }
    try {
      final client = await _googleSignIn.authenticatedClient();
      return client;
    } catch (e) {
      debugPrint('[AuthService] getAuthenticatedClient error: $e');
      return null;
    }
  }

  Future<void> _persistUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_auth_user', jsonEncode(user.toMap()));
  }

  /// Desktop OAuth2 loopback authentication using googleapis_auth.
  Future<AuthUser?> _signInDesktop({
    String? clientIdStr,
    String? clientSecretStr,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = (clientIdStr != null && clientIdStr.isNotEmpty)
        ? clientIdStr
        : prefs.getString('desktop_oauth_client_id') ?? '';
    final clientSecret = (clientSecretStr != null && clientSecretStr.isNotEmpty)
        ? clientSecretStr
        : prefs.getString('desktop_oauth_client_secret') ?? '';

    if (clientId.isEmpty) {
      throw StateError(
        'Desktop sign-in requires a Google Cloud OAuth 2.0 Desktop/Web Client ID. '
        'Please configure your Google Client ID.',
      );
    }

    await prefs.setString('desktop_oauth_client_id', clientId);
    if (clientSecret.isNotEmpty) {
      await prefs.setString('desktop_oauth_client_secret', clientSecret);
    }

    final id = gapis_auth.ClientId(clientId, clientSecret.isEmpty ? null : clientSecret);

    final client = await auth_io.clientViaUserConsent(
      id,
      [driveScope, 'email', 'profile'],
      (url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Please open this URL in your browser: $url');
        }
      },
    );

    _desktopAuthClient = client;

    // Cache credentials
    await prefs.setString(
      'desktop_oauth_credentials',
      jsonEncode({
        'type': client.credentials.accessToken.type,
        'data': client.credentials.accessToken.data,
        'expiry': client.credentials.accessToken.expiry.toIso8601String(),
        'refreshToken': client.credentials.refreshToken,
        'scopes': client.credentials.scopes,
        'idToken': client.credentials.idToken,
      }),
    );

    // Try to get user info from idToken or fallback
    String email = 'user@google.com';
    String name = 'Google User';
    String userId = 'desktop_user';

    if (client.credentials.idToken != null) {
      try {
        final parts = client.credentials.idToken!.split('.');
        if (parts.length >= 2) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final tokenMap = jsonDecode(payload) as Map<String, dynamic>;
          email = (tokenMap['email'] as String?) ?? email;
          name = (tokenMap['name'] as String?) ?? email;
          userId = (tokenMap['sub'] as String?) ?? userId;
        }
      } catch (_) {}
    }

    _currentUser = AuthUser(
      id: userId,
      email: email,
      displayName: name,
    );
    await _persistUser(_currentUser!);
    return _currentUser;
  }
}
