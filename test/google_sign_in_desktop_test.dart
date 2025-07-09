import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_desktop/google_sign_in_desktop.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  group(
    'GoogleSignInDesktop',
    () {
      late Completer<Request> revocationCompleter;
      late Completer<Request> tokenCompleter;
      late Completer<Request> userinfoCompleter;

      late Client client;
      late String Function(String codeVerifier) createCodeChallenge;
      late String Function(Random random) createCodeVerifier;
      late String Function(Random random) createState;
      late _GoogleSignInDesktopTokenDataStore tokenDataStore;

      setUp(
        () {
          revocationCompleter = Completer();

          tokenCompleter = Completer();

          userinfoCompleter = Completer();

          client = MockClient(
            (request) async {
              switch (request.url.path) {
                case '/revoke':
                  revocationCompleter.complete(request);
                  break;
                case '/token':
                  tokenCompleter.complete(request);
                  break;
                case '/v1/userinfo':
                  userinfoCompleter.complete(request);
                  break;
              }

              return Response(
                '',
                200,
              );
            },
          );

          createCodeChallenge = (_) {
            return 'TestCodeChallenge';
          };

          createCodeVerifier = (_) {
            return 'TestCodeVerifier';
          };

          createState = (_) {
            return 'TestState';
          };

          tokenDataStore = _GoogleSignInDesktopTokenDataStore();
        },
      );

      group(
        'authenticationEvents',
        () {
          test(
            'should return the authentication events stream',
            () {
              expect(
                GoogleSignInDesktop().authenticationEvents,
                isA<Stream<AuthenticationEvent>>(),
              );
            },
          );
        },
      );

      group(
        'customPostAuthPage',
        () {
          late GoogleSignInDesktopTokenData Function(
            Response response, {
            String? idToken,
            String? refreshToken,
          }) createTokenData;
          late GoogleSignInUserData Function(
            Response response, {
            String? idToken,
          }) createUserData;
          late Future<void> Function(
            Uri url,
          ) launchUrl;
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                );
              };

              createUserData = (
                response, {
                idToken,
              }) {
                return GoogleSignInUserData(
                  email: 'TestEmail',
                  id: 'TestId',
                  displayName: 'TestDisplayName',
                  photoUrl: 'TestPhotoUrl',
                );
              };

              plugin = GoogleSignInDesktop(
                client: client,
                createCodeChallenge: createCodeChallenge,
                createCodeVerifier: createCodeVerifier,
                createState: createState,
                createTokenData: createTokenData,
                createUserData: createUserData,
                launchUrl: (url) async {
                  return await launchUrl(url);
                },
              );
            },
          );

          test(
            'should respond with the custom post auth page if the custom post auth page is not null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.customPostAuthPage = 'TestCustomPostAuthPage';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      response = await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the responding to the server request
              }

              expect(
                response.body,
                'TestCustomPostAuthPage',
              );
            },
          );

          test(
            'should respond with the default post auth page if the custom post auth page is null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      response = await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the responding to the server request
              }

              expect(
                response.body,
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
</html>''',
              );
            },
          );
        },
      );

      group(
        'registerWith',
        () {
          test(
            'should register the desktop implementation of the plugin',
            () {
              GoogleSignInDesktop.registerWith();

              expect(
                GoogleSignInPlatform.instance,
                isA<GoogleSignInDesktop>(),
              );
            },
          );
        },
      );

      group(
        'attemptLightweightAuthentication',
        () {
          late GoogleSignInDesktopTokenData Function(
            Response response, {
            String? idToken,
            String? refreshToken,
          }) createTokenData;
          late GoogleSignInUserData Function(
            Response response, {
            String? idToken,
          }) createUserData;
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: refreshToken,
                );
              };

              createUserData = (
                response, {
                idToken,
              }) {
                return GoogleSignInUserData(
                  email: 'TestEmail',
                  id: 'TestId',
                  displayName: 'TestDisplayName',
                  photoUrl: 'TestPhotoUrl',
                );
              };

              plugin = GoogleSignInDesktop(
                client: client,
                createTokenData: createTokenData,
                createUserData: createUserData,
              );
            },
          );

          test(
            'should add an event to the authentication events stream if the token data is not null and the access token is not expired',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: false,
                );

              final authenticationEventCompleter =
                  Completer<AuthenticationEvent>();

              final subscription = plugin.authenticationEvents.listen(
                (authenticationEvent) {
                  authenticationEventCompleter.complete(authenticationEvent);
                },
              );

              await plugin.attemptLightweightAuthentication(
                AttemptLightweightAuthenticationParameters(),
              );

              expect(
                await authenticationEventCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                isA<AuthenticationEventSignIn>(),
              );

              await subscription.cancel();
            },
          );

          test(
            'should return authentication results if the token data is not null and the access token is not expired',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: false,
                );

              expect(
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                ),
                isNotNull,
              );
            },
          );

          test(
            'should return null if the token data is not null and the access token is expired and the refresh token is null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: null,
                  isExpired: true,
                );

              expect(
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                ),
                null,
              );
            },
          );

          test(
            'should return null if the token data is null',
            () async {
              plugin.tokenDataStore = tokenDataStore.._value = null;

              expect(
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                ),
                null,
              );
            },
          );

          test(
            'should send a token request if the token data is not null and the access token is expired and the refresh token is not null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: '',
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              try {
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                );
              } catch (e) {
                // ignored because we are testing the requesting of the token
              }

              final request = await tokenCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.scheme,
                'https',
              );

              expect(
                request.url.host,
                'oauth2.googleapis.com',
              );

              expect(
                request.url.path,
                '/token',
              );

              expect(
                request.bodyFields,
                containsPair(
                  'client_id',
                  'TestClientId',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'client_secret',
                  'TestClientSecret',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'refresh_token',
                  'TestRefreshToken',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'grant_type',
                  'refresh_token',
                ),
              );
            },
          );

          test(
            'should send a userinfo request if the token data is not null and the access token is not expired',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: false,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              try {
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                );
              } catch (e) {
                // ignored because we are testing the requesting of the userinfo
              }

              final request = await userinfoCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.scheme,
                'https',
              );

              expect(
                request.url.host,
                'openidconnect.googleapis.com',
              );

              expect(
                request.url.path,
                '/v1/userinfo',
              );

              expect(
                request.headers,
                containsPair(
                  'authorization',
                  'Bearer TestAccessToken',
                ),
              );
            },
          );

          test(
            'should store the token data if the token data is not null and the access token is expired and the refresh token is not null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: '',
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              try {
                await plugin.attemptLightweightAuthentication(
                  AttemptLightweightAuthenticationParameters(),
                );
              } catch (e) {
                // ignored because we are testing the storing of the token data
              }

              expect(
                tokenDataStore._value?.accessToken,
                'TestAccessToken',
              );
            },
          );

          test(
            'should throw an exception if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.attemptLightweightAuthentication(
                    AttemptLightweightAuthenticationParameters(),
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'authenticate',
        () {
          late GoogleSignInDesktopTokenData Function(
            Response response, {
            String? idToken,
            String? refreshToken,
          }) createTokenData;
          late GoogleSignInUserData Function(
            Response response, {
            String? idToken,
          }) createUserData;
          late Future<void> Function(
            Uri url,
          ) launchUrl;
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                );
              };

              createUserData = (
                response, {
                idToken,
              }) {
                return GoogleSignInUserData(
                  email: 'TestEmail',
                  id: 'TestId',
                  displayName: 'TestDisplayName',
                  photoUrl: 'TestPhotoUrl',
                );
              };

              plugin = GoogleSignInDesktop(
                client: client,
                createCodeChallenge: createCodeChallenge,
                createCodeVerifier: createCodeVerifier,
                createState: createState,
                createTokenData: createTokenData,
                createUserData: createUserData,
                launchUrl: (url) async {
                  return await launchUrl(url);
                },
              );
            },
          );

          test(
            'should add an event to the user data events stream',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authenticationEventCompleter =
                  Completer<AuthenticationEvent>();

              final subscription = plugin.authenticationEvents.listen(
                (authenticationEvent) {
                  authenticationEventCompleter.complete(authenticationEvent);
                },
              );

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              await Future.wait(
                [
                  (() async {
                    await plugin.authenticate(
                      AuthenticateParameters(
                        scopeHint: [
                          'openid',
                          'profile',
                          'email',
                        ],
                      ),
                    );
                  })(),
                  (() async {
                    final url = await authorizationCompleter.future.timeout(
                      const Duration(
                        seconds: 10,
                      ),
                    );

                    await get(
                      Uri.parse(
                        '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                      ),
                    );
                  })(),
                ],
              );

              expect(
                await authenticationEventCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                isA<AuthenticationEventSignIn>(),
              );

              await subscription.cancel();
            },
          );

          test(
            'should launch an authorization url',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Uri url;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      await get(
                        Uri.parse(
                          url.queryParameters['redirect_uri']!,
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the launching of the authorization url
              }

              expect(
                url.scheme,
                'https',
              );

              expect(
                url.host,
                'accounts.google.com',
              );

              expect(
                url.path,
                '/o/oauth2/auth',
              );

              expect(
                url.queryParameters,
                containsPair(
                  'client_id',
                  'TestClientId',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'redirect_uri',
                  matches(r'http\:\/\/127\.0\.0\.1\:\d+'),
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'response_type',
                  'code',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'scope',
                  'openid profile email',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'code_challenge',
                  'TestCodeChallenge',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'code_challenge_method',
                  'S256',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'state',
                  'TestState',
                ),
              );

              expect(
                url.queryParameters,
                containsPair(
                  'access_type',
                  'offline',
                ),
              );
            },
          );

          test(
            'should respond to the server request with the status code 200',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      response = await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the responding to the server request
              }

              expect(
                response.statusCode,
                200,
              );
            },
          );

          test(
            'should respond to the server request with the status code 500 if an exception was thrown',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      response = await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?error=invalid_request',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the responding to the server request
              }

              expect(
                response.statusCode,
                500,
              );
            },
          );

          test(
            'should send a token request',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late Uri url;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the requesting of the token
              }

              final request = await tokenCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.scheme,
                'https',
              );

              expect(
                request.url.host,
                'oauth2.googleapis.com',
              );

              expect(
                request.url.path,
                '/token',
              );

              expect(
                request.bodyFields,
                containsPair(
                  'client_id',
                  'TestClientId',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'client_secret',
                  'TestClientSecret',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'code',
                  'TestCode',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'code_verifier',
                  'TestCodeVerifier',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'grant_type',
                  'authorization_code',
                ),
              );

              expect(
                request.bodyFields,
                containsPair(
                  'redirect_uri',
                  url.queryParameters['redirect_uri'],
                ),
              );
            },
          );

          test(
            'should send a userinfo request',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the requesting of the userinfo
              }

              final request = await userinfoCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.scheme,
                'https',
              );

              expect(
                request.url.host,
                'openidconnect.googleapis.com',
              );

              expect(
                request.url.path,
                '/v1/userinfo',
              );

              expect(
                request.headers,
                containsPair(
                  'authorization',
                  'Bearer TestAccessToken',
                ),
              );
            },
          );

          test(
            'should store the token data',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: '',
                  refreshToken: null,
                );

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.authenticate(
                        AuthenticateParameters(
                          scopeHint: [
                            'openid',
                            'profile',
                            'email',
                          ],
                        ),
                      );
                    })(),
                    (() async {
                      final url = await authorizationCompleter.future.timeout(
                        const Duration(
                          seconds: 10,
                        ),
                      );

                      await get(
                        Uri.parse(
                          '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                        ),
                      );
                    })(),
                  ],
                );
              } catch (e) {
                // ignored because we are testing the storing of the token data
              }

              expect(
                tokenDataStore._value?.accessToken,
                'TestAccessToken',
              );

              expect(
                tokenDataStore._value?.refreshToken,
                'TestRefreshToken',
              );
            },
          );

          test(
            'should throw an exception if the server request does not have an error query parameter and does not have a code query parameter',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.authenticate(
                          AuthenticateParameters(
                            scopeHint: [
                              'openid',
                              'profile',
                              'email',
                            ],
                          ),
                        );
                      })(),
                      (() async {
                        final url = await authorizationCompleter.future.timeout(
                          const Duration(
                            seconds: 10,
                          ),
                        );

                        await get(
                          Uri.parse(
                            '${url.queryParameters['redirect_uri']!}?state=TestState',
                          ),
                        );
                      })(),
                    ],
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );

          test(
            'should throw an exception if the server request error query parameter is not null',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.authenticate(
                          AuthenticateParameters(
                            scopeHint: [
                              'openid',
                              'profile',
                              'email',
                            ],
                          ),
                        );
                      })(),
                      (() async {
                        final url = await authorizationCompleter.future.timeout(
                          const Duration(
                            seconds: 10,
                          ),
                        );

                        await get(
                          Uri.parse(
                            '${url.queryParameters['redirect_uri']!}?error=invalid_request',
                          ),
                        );
                      })(),
                    ],
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );

          test(
            'should throw an exception if the server request state query parameter does not equal the state',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.authenticate(
                          AuthenticateParameters(
                            scopeHint: [
                              'openid',
                              'profile',
                              'email',
                            ],
                          ),
                        );
                      })(),
                      (() async {
                        final url = await authorizationCompleter.future.timeout(
                          const Duration(
                            seconds: 10,
                          ),
                        );

                        await get(
                          Uri.parse(
                            '${url.queryParameters['redirect_uri']!}?state=InvalidState',
                          ),
                        );
                      })(),
                    ],
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );

          test(
            'should throw an exception if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.authenticate(
                    AuthenticateParameters(
                      scopeHint: [
                        'openid',
                        'profile',
                        'email',
                      ],
                    ),
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'clientAuthorizationTokensForScopes',
        () {
          late GoogleSignInDesktopTokenData Function(
            Response response, {
            String? idToken,
            String? refreshToken,
          }) createTokenData;
          late GoogleSignInUserData Function(
            Response response, {
            String? idToken,
          }) createUserData;
          late Future<void> Function(
            Uri url,
          ) launchUrl;
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              createUserData = (
                response, {
                idToken,
              }) {
                return GoogleSignInUserData(
                  email: 'TestEmail',
                  id: 'TestId',
                  displayName: 'TestDisplayName',
                  photoUrl: 'TestPhotoUrl',
                );
              };

              plugin = GoogleSignInDesktop(
                client: client,
                createCodeChallenge: createCodeChallenge,
                createCodeVerifier: createCodeVerifier,
                createState: createState,
                createTokenData: (
                  response, {
                  idToken,
                  refreshToken,
                }) {
                  return createTokenData(
                    response,
                    idToken: idToken,
                    refreshToken: refreshToken,
                  );
                },
                createUserData: createUserData,
                launchUrl: (url) async {
                  return await launchUrl(url);
                },
              );
            },
          );

          test(
            'should return null if the token data is null and prompt if unauthorized is false',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore.._value = null;

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                await plugin.clientAuthorizationTokensForScopes(
                  ClientAuthorizationTokensForScopesParameters(
                    request: AuthorizationRequestDetails(
                      scopes: [
                        'openid',
                        'profile',
                        'email',
                      ],
                      userId: null,
                      email: null,
                      promptIfUnauthorized: false,
                    ),
                  ),
                ),
                null,
              );
            },
          );

          test(
            'should return null if the token data is not null and the access token is expired and prompt if unauthorized is false',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: true,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                await plugin.clientAuthorizationTokensForScopes(
                  ClientAuthorizationTokensForScopesParameters(
                    request: AuthorizationRequestDetails(
                      scopes: [
                        'openid',
                        'profile',
                        'email',
                      ],
                      userId: null,
                      email: null,
                      promptIfUnauthorized: false,
                    ),
                  ),
                ),
                null,
              );
            },
          );

          test(
            'should return null if the token data is not null and the access token is not expired and the scopes have not been granted and prompt if unauthorized is false',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  scopes: [],
                  isExpired: false,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                await plugin.clientAuthorizationTokensForScopes(
                  ClientAuthorizationTokensForScopesParameters(
                    request: AuthorizationRequestDetails(
                      scopes: [
                        'openid',
                        'profile',
                        'email',
                      ],
                      userId: null,
                      email: null,
                      promptIfUnauthorized: false,
                    ),
                  ),
                ),
                null,
              );
            },
          );

          test(
            'should return client authorization token data if the token data is not null and the access token is not expired and the scopes have been granted and prompt if unauthorized is false',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  scopes: [
                    'openid',
                    'profile',
                    'email',
                  ],
                  isExpired: false,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                await plugin.clientAuthorizationTokensForScopes(
                  ClientAuthorizationTokensForScopesParameters(
                    request: AuthorizationRequestDetails(
                      scopes: [
                        'openid',
                        'profile',
                        'email',
                      ],
                      userId: null,
                      email: null,
                      promptIfUnauthorized: false,
                    ),
                  ),
                ),
                ClientAuthorizationTokenData(
                  accessToken: 'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should return client authorization token data if the token data is not null and the access token is not expired and the scopes have been granted with different names and prompt if unauthorized is false',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  scopes: [
                    'openid',
                    'https://www.googleapis.com/auth/userinfo.profile',
                    'https://www.googleapis.com/auth/userinfo.email',
                  ],
                  isExpired: false,
                );

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              expect(
                await plugin.clientAuthorizationTokensForScopes(
                  ClientAuthorizationTokensForScopesParameters(
                    request: AuthorizationRequestDetails(
                      scopes: [
                        'openid',
                        'profile',
                        'email',
                      ],
                      userId: null,
                      email: null,
                      promptIfUnauthorized: false,
                    ),
                  ),
                ),
                ClientAuthorizationTokenData(
                  accessToken: 'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should return client authorization token data if the token data is null and prompt if unauthorized is true',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore.._value = null;

              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                  scopes: [
                    'openid',
                    'profile',
                    'email',
                  ],
                );
              };

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late ClientAuthorizationTokenData? actual;

              await Future.wait(
                [
                  (() async {
                    actual = await plugin.clientAuthorizationTokensForScopes(
                      ClientAuthorizationTokensForScopesParameters(
                        request: AuthorizationRequestDetails(
                          scopes: [
                            'openid',
                            'profile',
                            'email',
                          ],
                          userId: null,
                          email: null,
                          promptIfUnauthorized: true,
                        ),
                      ),
                    );
                  })(),
                  (() async {
                    final url = await authorizationCompleter.future.timeout(
                      const Duration(
                        seconds: 10,
                      ),
                    );

                    await get(
                      Uri.parse(
                        '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                      ),
                    );
                  })(),
                ],
              );

              expect(
                actual,
                ClientAuthorizationTokenData(
                  accessToken: 'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should return client authorization token data if the token data is not null and the access token is expired and prompt if unauthorized is true',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: '',
                  isExpired: true,
                );

              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                  scopes: [
                    'openid',
                    'profile',
                    'email',
                  ],
                );
              };

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late ClientAuthorizationTokenData? actual;

              await Future.wait(
                [
                  (() async {
                    actual = await plugin.clientAuthorizationTokensForScopes(
                      ClientAuthorizationTokensForScopesParameters(
                        request: AuthorizationRequestDetails(
                          scopes: [
                            'openid',
                            'profile',
                            'email',
                          ],
                          userId: null,
                          email: null,
                          promptIfUnauthorized: true,
                        ),
                      ),
                    );
                  })(),
                  (() async {
                    final url = await authorizationCompleter.future.timeout(
                      const Duration(
                        seconds: 10,
                      ),
                    );

                    await get(
                      Uri.parse(
                        '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                      ),
                    );
                  })(),
                ],
              );

              expect(
                actual,
                ClientAuthorizationTokenData(
                  accessToken: 'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should return client authorization token data if the token data is not null and the access token is not expired and the scopes have not been granted and prompt if unauthorized is true',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: '',
                  scopes: [],
                  isExpired: false,
                );

              createTokenData = (
                response, {
                idToken,
                refreshToken,
              }) {
                return _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                  scopes: [
                    'openid',
                    'profile',
                    'email',
                  ],
                );
              };

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                InitParameters(
                  clientId: 'TestClientId',
                ),
              );

              late ClientAuthorizationTokenData? actual;

              await Future.wait(
                [
                  (() async {
                    actual = await plugin.clientAuthorizationTokensForScopes(
                      ClientAuthorizationTokensForScopesParameters(
                        request: AuthorizationRequestDetails(
                          scopes: [
                            'openid',
                            'profile',
                            'email',
                          ],
                          userId: null,
                          email: null,
                          promptIfUnauthorized: true,
                        ),
                      ),
                    );
                  })(),
                  (() async {
                    final url = await authorizationCompleter.future.timeout(
                      const Duration(
                        seconds: 10,
                      ),
                    );

                    await get(
                      Uri.parse(
                        '${url.queryParameters['redirect_uri']!}?state=TestState&code=TestCode',
                      ),
                    );
                  })(),
                ],
              );

              expect(
                actual,
                ClientAuthorizationTokenData(
                  accessToken: 'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.clientAuthorizationTokensForScopes(
                    ClientAuthorizationTokensForScopesParameters(
                      request: AuthorizationRequestDetails(
                        scopes: [
                          'openid',
                          'profile',
                          'email',
                        ],
                        userId: null,
                        email: null,
                        promptIfUnauthorized: false,
                      ),
                    ),
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'disconnect',
        () {
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              plugin = GoogleSignInDesktop(
                client: client,
              );
            },
          );

          test(
            'should add an event to the authentication events stream',
            () async {
              plugin.tokenDataStore = tokenDataStore;

              final authenticationEventCompleter =
                  Completer<AuthenticationEvent>();

              final subscription = plugin.authenticationEvents.listen(
                (authenticationEvent) {
                  authenticationEventCompleter.complete(authenticationEvent);
                },
              );

              await plugin.disconnect(
                DisconnectParams(),
              );

              expect(
                await authenticationEventCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                isA<AuthenticationEventSignOut>(),
              );

              await subscription.cancel();
            },
          );

          test(
            'should revoke the access token if the refresh token is null and the access token is not null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: null,
                );

              await plugin.disconnect(
                DisconnectParams(),
              );

              final request = await revocationCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.queryParameters,
                containsPair(
                  'token',
                  'TestAccessToken',
                ),
              );
            },
          );

          test(
            'should revoke the refresh token if the refresh token is not null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: 'TestRefreshToken',
                );

              await plugin.disconnect(
                DisconnectParams(),
              );

              final request = await revocationCompleter.future.timeout(
                const Duration(
                  seconds: 10,
                ),
              );

              expect(
                request.url.queryParameters,
                containsPair(
                  'token',
                  'TestRefreshToken',
                ),
              );
            },
          );

          test(
            'should set the stored token data to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                );

              await plugin.disconnect(
                DisconnectParams(),
              );

              expect(
                tokenDataStore._value,
                null,
              );
            },
          );

          test(
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.disconnect(
                    DisconnectParams(),
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'signOut',
        () {
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              plugin = GoogleSignInDesktop();
            },
          );

          test(
            'should add an event to the authentication events stream',
            () async {
              plugin.tokenDataStore = tokenDataStore;

              final authenticationEventCompleter =
                  Completer<AuthenticationEvent>();

              final subscription = plugin.authenticationEvents.listen(
                (authenticationEvent) {
                  authenticationEventCompleter.complete(authenticationEvent);
                },
              );

              await plugin.signOut(
                SignOutParams(),
              );

              expect(
                await authenticationEventCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                isA<AuthenticationEventSignOut>(),
              );

              await subscription.cancel();
            },
          );

          test(
            'should set the stored token data to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                );

              await plugin.signOut(
                SignOutParams(),
              );

              expect(
                tokenDataStore._value,
                null,
              );
            },
          );

          test(
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.signOut(
                    SignOutParams(),
                  );
                },
                throwsA(
                  isA<GoogleSignInException>(),
                ),
              );
            },
          );
        },
      );

      tearDown(
        () {
          client.close();
        },
      );
    },
  );
}

class _GoogleSignInDesktopTokenData extends GoogleSignInDesktopTokenData {
  final bool? _isExpired;

  _GoogleSignInDesktopTokenData({
    required super.accessToken,
    super.refreshToken,
    super.scopes,
    bool? isExpired,
  }) : _isExpired = isExpired;

  @override
  bool? isExpired() {
    return _isExpired;
  }
}

class _GoogleSignInDesktopTokenDataStore
    implements GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> {
  GoogleSignInDesktopTokenData? _value;

  @override
  Future<GoogleSignInDesktopTokenData?> get() async {
    return _value;
  }

  @override
  Future<void> set(
    GoogleSignInDesktopTokenData? value,
  ) async {
    _value = value;
  }
}
