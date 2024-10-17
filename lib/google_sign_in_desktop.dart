library google_sign_in_desktop;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'src/create_code_challenge.dart' as create_code_challenge;
import 'src/create_code_verifier.dart' as create_code_verifier;
import 'src/create_state.dart' as create_state;
import 'src/create_token_data.dart' as create_token_data;
import 'src/create_user_data.dart' as create_user_data;
import 'src/exceptions/authorization_request_exception.dart';
import 'src/exceptions/state_validation_exception.dart';
import 'src/google_sign_in_desktop_store.dart';
import 'src/google_sign_in_desktop_token_data.dart';

export 'src/google_sign_in_desktop_store.dart';
export 'src/google_sign_in_desktop_token_data.dart';

/// Error code indicating there was a failed attempt to recover user authentication.
const _kFailedToRecoverAuthError = 'failed_to_recover_auth';

/// Error code indicating that attempt to sign in failed.
const _kSignInFailedError = 'sign_in_failed';

/// Error code indicating there is no signed in user and interactive sign in flow is required.
const _kSignInRequiredError = 'sign_in_required';

/// Error code indicating that authentication can be recovered with user action.
const _kUserRecoverableAuthError = 'user_recoverable_auth';

/// The desktop implementation of `google_sign_in`.
class GoogleSignInDesktop extends GoogleSignInPlatform {
  /// The client that sends the token request, the userinfo request, and the revocation request.
  final Client _client;

  /// The function that creates a code challenge.
  final String Function(
    String codeVerifier,
  ) _createCodeChallenge;

  /// The function that creates a code verifier.
  final String Function(
    Random random,
  ) _createCodeVerifier;

  /// The function that creates a state.
  final String Function(
    Random random,
  ) _createState;

  /// The function that creates a token data.
  final GoogleSignInDesktopTokenData Function(
    Response response, {
    String? idToken,
    String? refreshToken,
  }) _createTokenData;

  /// The function that creates a user data.
  final GoogleSignInUserData Function(
    Response response, {
    String? idToken,
  }) _createUserData;

  /// The function that launches a url.
  final Future<void> Function(
    Uri url,
  ) _launchUrl;

  /// The random that generates random cryptographic values.
  final Random _random;

  /// The stream controller that controls the user data events stream.
  final StreamController<GoogleSignInUserData?> _userDataEvents;

  late String _clientId;
  late String _clientSecret;
  late List<String> _scopes;
  late GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> _tokenDataStore;
  GoogleSignInUserData? _userData;

  GoogleSignInDesktop({
    Client? client,
    String Function(
      String codeVerifier,
    )? createCodeChallenge,
    String Function(
      Random random,
    )? createCodeVerifier,
    String Function(
      Random random,
    )? createState,
    GoogleSignInDesktopTokenData Function(
      Response response, {
      String? idToken,
      String? refreshToken,
    })? createTokenData,
    GoogleSignInUserData Function(
      Response response, {
      String? idToken,
    })? createUserData,
    Future<void> Function(
      Uri url,
    )? launchUrl,
    Random? random,
    StreamController<GoogleSignInUserData?>? userDataEvents,
  })  : _client = client ?? Client(),
        _createCodeChallenge =
            createCodeChallenge ?? create_code_challenge.createCodeChallenge,
        _createCodeVerifier =
            createCodeVerifier ?? create_code_verifier.createCodeVerifier,
        _createState = createState ?? create_state.createState,
        _createTokenData = createTokenData ?? create_token_data.createTokenData,
        _createUserData = createUserData ?? create_user_data.createUserData,
        _launchUrl = launchUrl ?? url_launcher.launchUrl,
        _random = random ?? Random.secure(),
        _userDataEvents = userDataEvents ?? StreamController.broadcast();

  @override
  Stream<GoogleSignInUserData?> get userDataEvents {
    return _userDataEvents.stream;
  }

  /// Sets the client secret that is used in token requests.
  set clientSecret(
    String clientSecret,
  ) {
    _clientSecret = clientSecret;
  }

  /// Sets the token data store that is used to store tokens between sessions.
  set tokenDataStore(
    GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> tokenDataStore,
  ) {
    _tokenDataStore = tokenDataStore;
  }

  /// Registers the desktop implementation of `google_sign_in`.
  static void registerWith() {
    GoogleSignInPlatform.instance = GoogleSignInDesktop();
  }

  @override
  Future<void> clearAuthCache({
    required String token,
  }) async {
    final tokenData = await _tokenDataStore.get();

    await _tokenDataStore.set(
      GoogleSignInDesktopTokenData(
        idToken: tokenData?.idToken,
        accessToken: null,
        refreshToken: tokenData?.refreshToken,
        expiration: null,
        scopes: null,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    final tokenData = await _tokenDataStore.get();

    final token = tokenData?.refreshToken ?? tokenData?.accessToken;
    if (token != null) {
      await _client.post(
        Uri.https(
          'oauth2.googleapis.com',
          '/revoke',
          {
            'token': token,
          },
        ),
      );
    }

    await _tokenDataStore.set(null);

    _userData = null;

    _userDataEvents.add(_userData);
  }

  @override
  Future<GoogleSignInDesktopTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    var tokenData = await _tokenDataStore.get();

    if (tokenData == null) {
      throw PlatformException(
        code: _kSignInRequiredError,
      );
    }

    if (tokenData.isExpired() == false) {
      return tokenData;
    }

    final refreshToken = tokenData.refreshToken;
    if (refreshToken != null) {
      tokenData = _createTokenData(
        await _client.post(
          Uri.https(
            'oauth2.googleapis.com',
            '/token',
          ),
          body: {
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'refresh_token': refreshToken,
            'grant_type': 'refresh_token',
          },
        ),
        idToken: tokenData.idToken,
        refreshToken: refreshToken,
      );

      await _tokenDataStore.set(tokenData);

      return tokenData;
    }

    if (shouldRecoverAuth == true) {
      try {
        return (await _signIn()).$1;
      } catch (e) {
        throw PlatformException(
          code: _kFailedToRecoverAuthError,
          message: '$e',
        );
      }
    }

    throw PlatformException(
      code: _kUserRecoverableAuthError,
    );
  }

  @override
  Future<void> init({
    List<String> scopes = const <String>[],
    SignInOption signInOption = SignInOption.standard,
    String? hostedDomain,
    String? clientId,
  }) async {
    _clientId = ArgumentError.checkNotNull(clientId, 'clientId');
    _scopes = _buildEffectiveScopes(scopes);
  }

  List<String> _buildEffectiveScopes(List<String> scopes) {
    return {...scopes, 'openid', 'profile', 'email'}.toList();
  }

  @override
  Future<bool> isSignedIn() async {
    return _userData != null;
  }

  @override
  Future<GoogleSignInUserData?> signIn() async {
    try {
      return (await _signIn()).$2;
    } catch (e) {
      throw PlatformException(
        code: _kSignInFailedError,
        message: '$e',
      );
    }
  }

  @override
  Future<GoogleSignInUserData?> signInSilently() async {
    try {
      var tokenData = await _tokenDataStore.get();
      if (tokenData != null) {
        if (tokenData.isExpired() != false) {
          final refreshToken = tokenData.refreshToken;
          if (refreshToken != null) {
            tokenData = _createTokenData(
              await _client.post(
                Uri.https(
                  'oauth2.googleapis.com',
                  '/token',
                ),
                body: {
                  'client_id': _clientId,
                  'client_secret': _clientSecret,
                  'refresh_token': refreshToken,
                  'grant_type': 'refresh_token',
                },
              ),
              idToken: tokenData.idToken,
              refreshToken: refreshToken,
            );

            await _tokenDataStore.set(tokenData);
          }
        }

        if (tokenData.isExpired() == false) {
          _userData = _createUserData(
            await _client.post(
              Uri.https(
                'openidconnect.googleapis.com',
                '/v1/userinfo',
              ),
              headers: {
                'authorization': 'Bearer ${tokenData.accessToken!}',
              },
            ),
            idToken: tokenData.idToken,
          );

          _userDataEvents.add(_userData);

          return _userData;
        }
      }
    } catch (e) {
      throw PlatformException(
        code: _kSignInFailedError,
        message: '$e',
      );
    }

    throw PlatformException(
      code: _kSignInRequiredError,
    );
  }

  @override
  Future<void> signOut() async {
    await _tokenDataStore.set(null);

    _userData = null;

    _userDataEvents.add(_userData);
  }

  Future<_Tuple2<GoogleSignInDesktopTokenData, GoogleSignInUserData>>
      _signIn() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    try {
      final redirectUri = 'http://${server.address.host}:${server.port}';

      // https://developers.google.com/identity/protocols/oauth2/native-app#step1-code-verifier

      final codeVerifier = _createCodeVerifier(_random);

      final codeChallenge = _createCodeChallenge(codeVerifier);

      // https://developers.google.com/identity/protocols/oauth2/native-app#step-2:-send-a-request-to-googles-oauth-2.0-server

      final state = _createState(_random);

      await _launchUrl(
        Uri.https(
          'accounts.google.com',
          '/o/oauth2/auth',
          {
            'client_id': _clientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': _scopes.join(' '),
            'code_challenge': codeChallenge,
            'code_challenge_method': 'S256',
            'state': state,
          },
        ),
      );

      // https://developers.google.com/identity/protocols/oauth2/native-app#handlingresponse

      final request = await server.first;

      try {
        final error = request.uri.queryParameters['error'];
        if (error != null) {
          throw AuthorizationRequestException(
            error: error,
          );
        }

        if (request.uri.queryParameters['state'] != state) {
          throw const StateValidationException();
        }

        final code = request.uri.queryParameters['code']!;

        // https://developers.google.com/identity/protocols/oauth2/native-app#exchange-authorization-code

        final tokenData = _createTokenData(
          await _client.post(
            Uri.https(
              'oauth2.googleapis.com',
              '/token',
            ),
            body: {
              'client_id': _clientId,
              'client_secret': _clientSecret,
              'code': code,
              'code_verifier': codeVerifier,
              'grant_type': 'authorization_code',
              'redirect_uri': redirectUri,
            },
          ),
        );

        await _tokenDataStore.set(tokenData);

        final userData = _userData = _createUserData(
          await _client.post(
            Uri.https(
              'openidconnect.googleapis.com',
              '/v1/userinfo',
            ),
            headers: {
              'authorization': 'Bearer ${tokenData.accessToken!}',
            },
          ),
          idToken: tokenData.idToken,
        );

        _userDataEvents.add(userData);

        request.response
          ..statusCode = 200
          ..headers.set('content-type', 'text/html; charset=UTF-8')
          ..write('''<!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>Authorization successful.</title>
          </head>
          <body>
            <h2 style="text-align: center">Application has successfully obtained access credentials</h2>
            <p style="text-align: center">This window can be closed now.</p>
          </body>
        </html>''');

        await request.response.close();

        return _Tuple2(tokenData, userData);
      } catch (e) {
        request.response.statusCode = 500;

        await request.response.close().catchError((_) {});

        rethrow;
      }
    } finally {
      await server.close();
    }
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<bool> requestScopes(List<String> requestedScopes) async {
    if (requestedScopes.isEmpty) {
      return false;
    }

    // Keep track of the previous scopes in case we need to revert
    final previousScopes = _scopes;

    try {
      // Merge the current scopes with the requested scopes.
      _scopes =
          _buildEffectiveScopes({..._scopes, ...requestedScopes}.toList());

      GoogleSignInDesktopTokenData tokenData;
      final String? email = _userData?.email;
      if (email == null) {
        // Not signed in, so fresh sign in with the new scopes
        final signInRes = await _signIn();
        tokenData = signInRes.$1;
      } else {
        // Already signed in, so get the token data to see if the scopes are already granted
        tokenData = await getTokens(email: email, shouldRecoverAuth: false);
      }

      assert(tokenData.scopes != null);
      final tokenScopes = tokenData.scopes ?? [];

      final hasGrantedScopes = _hasGrantedAllScopes(
        queryScopes: requestedScopes,
        grantedScopes: tokenScopes,
      );

      if (email == null) {
        // It was a fresh sign in, so just return whatever we get
        return hasGrantedScopes;
      }

      if (hasGrantedScopes) {
        return true;
      }

      // The requested scopes are not granted, so try to sign in with the new scopes
      final tokenData2nd = (await _signIn()).$1;
      assert(tokenData2nd.scopes != null);
      final tokenScopes2nd = tokenData2nd.scopes ?? [];

      return _hasGrantedAllScopes(
        queryScopes: requestedScopes,
        grantedScopes: tokenScopes2nd,
      );
    } catch (_) {
      // If something goes wrong, revert the scopes back to the previous state
      _scopes = previousScopes;
      rethrow;
    }
  }

  @override
  Future<bool> canAccessScopes(List<String> scopes,
      {String? accessToken}) async {
    var tokenData = await _tokenDataStore.get();

    if (tokenData == null || tokenData.accessToken != accessToken) {
      return false;
    }

    final isTokenValid = tokenData.isExpired() == false;

    return isTokenValid &&
        _hasGrantedAllScopes(
          queryScopes: scopes,
          grantedScopes: tokenData.scopes!,
        );
  }

  bool _hasGrantedAllScopes({
    required List<String> queryScopes,
    required List<String> grantedScopes,
  }) {
    return queryScopes.every((scope) {
      final contained = grantedScopes.contains(scope);
      if (contained) {
        return true;
      }
      final altScopeName = _getAlternativeScopeName(scope);
      return altScopeName != null && grantedScopes.contains(altScopeName);
    });
  }

  /// The scope in the http response can have a different name than the one requested.
  String? _getAlternativeScopeName(String scope) {
    switch (scope) {
      case 'email':
        return 'https://www.googleapis.com/auth/userinfo.email';
      case 'profile':
        return 'https://www.googleapis.com/auth/userinfo.profile';
      default:
        return null;
    }
  }
}

class _Tuple2<T1, T2> {
  final T1 $1;
  final T2 $2;

  const _Tuple2(this.$1, this.$2);
}
