import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
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
        'userDataEvents',
        () {
          test(
            'should return the user data events stream',
            () {
              expect(
                GoogleSignInDesktop().userDataEvents,
                isA<Stream<GoogleSignInUserData?>>(),
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
        'clearAuthCache',
        () {
          late GoogleSignInDesktop plugin;

          setUp(
            () {
              plugin = GoogleSignInDesktop();
            },
          );

          test(
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.clearAuthCache(
                    token: '',
                  );
                },
                throwsA(
                  isA<Error>(),
                ),
              );
            },
          );

          test(
            'should set the access token to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                );

              await plugin.clearAuthCache(
                token: '',
              );

              expect(
                tokenDataStore._value?.accessToken,
                null,
              );
            },
          );

          test(
            'should set the expiration to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = GoogleSignInDesktopTokenData(
                  expiration: DateTime.now(),
                );

              await plugin.clearAuthCache(
                token: '',
              );

              expect(
                tokenDataStore._value?.expiration,
                null,
              );
            },
          );

          test(
            'should set the scopes to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  scopes: ['openid profile email'],
                );

              await plugin.clearAuthCache(
                token: '',
              );

              expect(
                tokenDataStore._value?.scopes,
                null,
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
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.disconnect();
                },
                throwsA(
                  isA<Error>(),
                ),
              );
            },
          );

          test(
            'should revoke the refresh token if the refresh token is not null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: null,
                  refreshToken: 'TestRefreshToken',
                );

              await plugin.disconnect();

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
            'should revoke the access token if the refresh token is null and the access token is not null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  refreshToken: null,
                );

              await plugin.disconnect();

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
            'should set the stored token data to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData();

              await plugin.disconnect();

              expect(
                tokenDataStore._value,
                null,
              );
            },
          );

          test(
            'should add an event to the user data events stream',
            () async {
              plugin.tokenDataStore = tokenDataStore;

              final userDataCompleter = Completer<GoogleSignInUserData?>();

              final subscription = plugin.userDataEvents.listen(
                (userData) {
                  userDataCompleter.complete(userData);
                },
              );

              await plugin.disconnect();

              expect(
                await userDataCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                null,
              );

              await subscription.cancel();
            },
          );
        },
      );

      group(
        'getTokens',
        () {
          late GoogleSignInDesktopTokenData Function(
            Response response, {
            String? idToken,
            String? refreshToken,
          }) createTokenData;
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
                  refreshToken: refreshToken,
                );
              };

              plugin = GoogleSignInDesktop(
                client: client,
                createCodeChallenge: createCodeChallenge,
                createCodeVerifier: createCodeVerifier,
                createState: createState,
                createTokenData: createTokenData,
                launchUrl: (url) async {
                  return await launchUrl(url);
                },
              );
            },
          );

          test(
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.getTokens(
                    email: '',
                  );
                },
                throwsA(
                  isA<Error>(),
                ),
              );
            },
          );

          test(
            'should throw an exception if the token data is null',
            () {
              plugin.tokenDataStore = tokenDataStore.._value = null;

              expect(
                () async {
                  await plugin.getTokens(
                    email: '',
                  );
                },
                throwsA(
                  isA<PlatformException>(),
                ),
              );
            },
          );

          test(
            'should return the token data if the access token is not expired',
            () async {
              final tokenData = _GoogleSignInDesktopTokenData(
                isExpired: false,
              );

              plugin.tokenDataStore = tokenDataStore.._value = tokenData;

              expect(
                await plugin.getTokens(
                  email: '',
                ),
                tokenData,
              );
            },
          );

          test(
            'should send a token request if the access token is expired and the refresh token is not null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await plugin.getTokens(
                  email: '',
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
            'should store the token data if the access token is refreshed',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: null,
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              final tokenData = await plugin.getTokens(
                email: '',
              );

              expect(
                tokenDataStore._value,
                tokenData,
              );
            },
          );

          test(
            'should return the token data if the access token is refreshed',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: null,
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              final tokenData = await plugin.getTokens(
                email: '',
              );

              expect(
                tokenData.accessToken,
                'TestAccessToken',
              );

              expect(
                tokenData.refreshToken,
                'TestRefreshToken',
              );
            },
          );

          test(
            'should launch an authorization url if the access token is expired and the refresh token is null and should recover auth is true',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  refreshToken: null,
                  isExpired: true,
                );

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late Uri url;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.getTokens(
                        email: '',
                        shouldRecoverAuth: true,
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
            'should throw an exception if the access token is expired and the refresh token is null and should recover auth is false',
            () {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  refreshToken: null,
                  isExpired: true,
                );

              expect(
                () async {
                  await plugin.getTokens(
                    email: '',
                    shouldRecoverAuth: false,
                  );
                },
                throwsA(
                  isA<PlatformException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'isSignedIn',
        () {
          test(
            'should return false if the user is not signed in',
            () async {
              expect(
                await GoogleSignInDesktop().isSignedIn(),
                false,
              );
            },
          );
        },
      );

      group(
        'signIn',
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
                  idToken: idToken ?? 'TestIdToken',
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
            'should launch an authorization url',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late Uri url;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
            'should throw an exception if the server request error query parameter is not null',
            () async {
              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.signIn();
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
                  isA<PlatformException>(),
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
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.signIn();
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
                  isA<PlatformException>(),
                ),
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
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              expect(
                () async {
                  await Future.wait(
                    [
                      (() async {
                        await plugin.signIn();
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
                  isA<PlatformException>(),
                ),
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
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late Uri url;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
            'should store the token data',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: null,
                  refreshToken: null,
                );

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
            'should send a userinfo request',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
            'should add an event to the user data events stream',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore;

              final userDataCompleter = Completer<GoogleSignInUserData?>();

              final subscription = plugin.userDataEvents.listen(
                (userData) {
                  userDataCompleter.complete(userData);
                },
              );

              final authorizationCompleter = Completer<Uri>();

              launchUrl = (url) async {
                authorizationCompleter.complete(url);
              };

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late GoogleSignInUserData? userData;

              await Future.wait(
                [
                  (() async {
                    userData = await plugin.signIn();
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
                await userDataCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                userData,
              );

              await subscription.cancel();
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
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              late Response response;

              try {
                await Future.wait(
                  [
                    (() async {
                      await plugin.signIn();
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
            'should throw an exception if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.signIn();
                },
                throwsA(
                  isA<PlatformException>(),
                ),
              );
            },
          );
        },
      );

      group(
        'signInSilently',
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
                  idToken: idToken ?? 'TestIdToken',
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
            'should send a token request if the access token is expired and the refresh token is not null',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await plugin.signInSilently();
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
            'should store the token data if the access token is refreshed',
            () async {
              plugin.clientSecret = 'TestClientSecret';

              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: null,
                  refreshToken: 'TestRefreshToken',
                  isExpired: true,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await plugin.signInSilently();
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
            'should send a userinfo request if the access token is not expired',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: false,
                );

              await plugin.init(
                scopes: ['openid', 'profile', 'email'],
                clientId: 'TestClientId',
              );

              try {
                await plugin.signInSilently();
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
            'should add an event to the user data events stream if the access token is not expired',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData(
                  accessToken: 'TestAccessToken',
                  isExpired: false,
                );

              final userDataCompleter = Completer<GoogleSignInUserData?>();

              final subscription = plugin.userDataEvents.listen(
                (userData) {
                  userDataCompleter.complete(userData);
                },
              );

              final userData = await plugin.signInSilently();

              expect(
                await userDataCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                userData,
              );

              await subscription.cancel();
            },
          );

          test(
            'should throw an exception if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.signInSilently();
                },
                throwsA(
                  isA<PlatformException>(),
                ),
              );
            },
          );

          test(
            'should throw an exception if the token data is null',
            () {
              plugin.tokenDataStore = tokenDataStore.._value = null;

              expect(
                () async {
                  await plugin.signInSilently();
                },
                throwsA(
                  isA<PlatformException>(),
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
            'should throw an error if the token data store has not been set',
            () {
              expect(
                () async {
                  await plugin.signOut();
                },
                throwsA(
                  isA<Error>(),
                ),
              );
            },
          );

          test(
            'should set the stored token data to null',
            () async {
              plugin.tokenDataStore = tokenDataStore
                .._value = _GoogleSignInDesktopTokenData();

              await plugin.signOut();

              expect(
                tokenDataStore._value,
                null,
              );
            },
          );

          test(
            'should add an event to the user data events stream',
            () async {
              plugin.tokenDataStore = tokenDataStore;

              final userDataCompleter = Completer<GoogleSignInUserData?>();

              final subscription = plugin.userDataEvents.listen(
                (userData) {
                  userDataCompleter.complete(userData);
                },
              );

              await plugin.signOut();

              expect(
                await userDataCompleter.future.timeout(
                  const Duration(
                    seconds: 10,
                  ),
                ),
                null,
              );

              await subscription.cancel();
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
    super.accessToken,
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
