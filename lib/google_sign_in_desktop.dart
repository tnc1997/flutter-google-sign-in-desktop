library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'src/exceptions/authorization_request_exception.dart';
import 'src/exceptions/state_validation_exception.dart';
import 'src/functions/create_code_challenge.dart' as code_challenge_creator;
import 'src/functions/create_code_verifier.dart' as code_verifier_creator;
import 'src/functions/create_state.dart' as state_creator;
import 'src/functions/create_token_data.dart' as token_data_creator;
import 'src/functions/create_user_data.dart' as user_data_creator;
import 'src/google_sign_in_desktop_store.dart';
import 'src/google_sign_in_desktop_token_data.dart';

export 'src/google_sign_in_desktop_store.dart';
export 'src/google_sign_in_desktop_token_data.dart';

/// This scope value requests access to the email and email_verified claims.
const _kOpenidEmailScope = 'email';

/// This scope value requests access to the sub claim.
const _kOpenidOpenidScope = 'openid';

/// This scope value requests access to the end-user's default profile claims, which are: name, family_name, given_name, middle_name, nickname, preferred_username, profile, picture, website, gender, birthdate, zoneinfo, locale, and updated_at.
const _kOpenidProfileScope = 'profile';

/// See your primary Google Account email address.
const _kUserinfoEmailScope = 'https://www.googleapis.com/auth/userinfo.email';

/// See your personal info, including any personal info you've made publicly available.
const _kUserinfoProfileScope =
    'https://www.googleapis.com/auth/userinfo.profile';

/// The desktop implementation of `google_sign_in`.
class GoogleSignInDesktop extends GoogleSignInPlatform {
  /// The stream controller that controls the authentication events stream.
  final StreamController<AuthenticationEvent> _authenticationEvents;

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
    Response response,
  ) _createUserData;

  /// The function that launches a url.
  final Future<void> Function(
    Uri url,
  ) _launchUrl;

  /// The random that generates random cryptographic values.
  final Random _random;

  late String _clientId;
  late String _clientSecret;
  String? _customPostAuthPage;
  late GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> _tokenDataStore;

  GoogleSignInDesktop({
    StreamController<AuthenticationEvent>? authenticationEvents,
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
      Response response,
    )? createUserData,
    Future<void> Function(
      Uri url,
    )? launchUrl,
    Random? random,
  })  : _authenticationEvents =
            authenticationEvents ?? StreamController.broadcast(),
        _client = client ?? Client(),
        _createCodeChallenge =
            createCodeChallenge ?? code_challenge_creator.createCodeChallenge,
        _createCodeVerifier =
            createCodeVerifier ?? code_verifier_creator.createCodeVerifier,
        _createState = createState ?? state_creator.createState,
        _createTokenData =
            createTokenData ?? token_data_creator.createTokenData,
        _createUserData = createUserData ?? user_data_creator.createUserData,
        _launchUrl = launchUrl ?? url_launcher.launchUrl,
        _random = random ?? Random.secure();

  @override
  Stream<AuthenticationEvent> get authenticationEvents {
    return _authenticationEvents.stream;
  }

  /// Sets the client secret that is used in token requests.
  set clientSecret(
    String clientSecret,
  ) {
    _clientSecret = clientSecret;
  }

  /// Sets the HTML for the page that is shown to the user after they have authenticated successfully.
  set customPostAuthPage(
    String? customPostAuthPage,
  ) {
    _customPostAuthPage = customPostAuthPage;
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
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    try {
      if (await _tokenDataStore.get() case var tokenData?) {
        if (tokenData.isExpired() != false) {
          if (tokenData.refreshToken case final refreshToken?) {
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
          final userData = _createUserData(
            await _client.post(
              Uri.https(
                'openidconnect.googleapis.com',
                '/v1/userinfo',
              ),
              headers: {
                'authorization': 'Bearer ${tokenData.accessToken}',
              },
            ),
          );

          _authenticationEvents.add(
            AuthenticationEventSignIn(
              user: userData,
              authenticationTokens: AuthenticationTokenData(
                idToken: null,
              ),
            ),
          );

          return AuthenticationResults(
            user: userData,
            authenticationTokens: AuthenticationTokenData(
              idToken: null,
            ),
          );
        }
      }

      return null;
    } catch (e) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: e.toString(),
      );
    }
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    try {
      final (tokenData, userData) = await _signIn(
        scopes: params.scopeHint,
      );

      await _tokenDataStore.set(tokenData);

      _authenticationEvents.add(
        AuthenticationEventSignIn(
          user: userData,
          authenticationTokens: AuthenticationTokenData(
            idToken: tokenData.idToken,
          ),
        ),
      );

      return AuthenticationResults(
        user: userData,
        authenticationTokens: AuthenticationTokenData(
          idToken: tokenData.idToken,
        ),
      );
    } catch (e) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: e.toString(),
      );
    }
  }

  @override
  bool authorizationRequiresUserInteraction() {
    return false;
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    try {
      if (await _tokenDataStore.get() case final tokenData?) {
        if (tokenData.isExpired() == false) {
          if (_hasGrantedAllScopes(tokenData, params.request.scopes)) {
            return ClientAuthorizationTokenData(
              accessToken: tokenData.accessToken,
            );
          }
        }
      }

      if (params.request.promptIfUnauthorized == false) {
        return null;
      }

      final (tokenData, userData) = await _signIn(
        scopes: params.request.scopes,
      );

      await _tokenDataStore.set(tokenData);

      _authenticationEvents.add(
        AuthenticationEventSignIn(
          user: userData,
          authenticationTokens: AuthenticationTokenData(
            idToken: tokenData.idToken,
          ),
        ),
      );

      return ClientAuthorizationTokenData(
        accessToken: tokenData.accessToken,
      );
    } catch (e) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: e.toString(),
      );
    }
  }

  @override
  Future<void> disconnect(
    DisconnectParams params,
  ) async {
    try {
      final tokenData = await _tokenDataStore.get();

      if (tokenData?.refreshToken ?? tokenData?.accessToken case final token?) {
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

      _authenticationEvents.add(
        AuthenticationEventSignOut(),
      );
    } catch (e) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: e.toString(),
      );
    }
  }

  @override
  Future<void> init(
    InitParameters params,
  ) async {
    _clientId = ArgumentError.checkNotNull(params.clientId, 'clientId');
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async {
    throw UnsupportedError(
      'serverAuthorizationTokensForScopes is not supported by google_sign_in_desktop.',
    );
  }

  @override
  Future<void> signOut(
    SignOutParams params,
  ) async {
    try {
      await _tokenDataStore.set(null);

      _authenticationEvents.add(
        AuthenticationEventSignOut(),
      );
    } catch (e) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: e.toString(),
      );
    }
  }

  @override
  bool supportsAuthenticate() {
    return true;
  }

  bool _hasGrantedAllScopes(
    GoogleSignInDesktopTokenData tokenData,
    List<String> scopes,
  ) {
    if (tokenData.scopes case final tokenScopes?) {
      return scopes.every(
        (scope) {
          return tokenScopes.any((tokenScope) {
            return scope == tokenScope ||
                (scope == _kOpenidEmailScope &&
                    tokenScope == _kUserinfoEmailScope) ||
                (scope == _kOpenidProfileScope &&
                    tokenScope == _kUserinfoProfileScope);
          });
        },
      );
    }

    return false;
  }

  Future<(GoogleSignInDesktopTokenData, GoogleSignInUserData)> _signIn({
    List<String> scopes = const [],
  }) async {
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
            'scope': {
              ...scopes,
              _kOpenidOpenidScope,
              _kOpenidProfileScope,
              _kOpenidEmailScope,
            }.join(' '),
            'code_challenge': codeChallenge,
            'code_challenge_method': 'S256',
            'state': state,
            // https://developers.google.com/identity/protocols/oauth2/web-server#offline
            'access_type': 'offline',
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

        final userData = _createUserData(
          await _client.post(
            Uri.https(
              'openidconnect.googleapis.com',
              '/v1/userinfo',
            ),
            headers: {
              'authorization': 'Bearer ${tokenData.accessToken}',
            },
          ),
        );

        request.response
          ..statusCode = 200
          ..headers.set('content-type', 'text/html; charset=UTF-8')
          ..write(_customPostAuthPage ??
              '''<!DOCTYPE html>
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

        return (tokenData, userData);
      } catch (e) {
        request.response.statusCode = 500;

        await request.response.close().catchError((_) {});

        rethrow;
      }
    } finally {
      await server.close();
    }
  }
}
