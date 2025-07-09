import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_desktop/google_sign_in_desktop.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';

const clientId =
    'YOUR_GOOGLE_SIGN_IN_OAUTH_CLIENT_ID.apps.googleusercontent.com';

const scopes = [
  'https://www.googleapis.com/auth/contacts.readonly',
];

void main() {
  if (GoogleSignInPlatform.instance case GoogleSignInDesktop instance) {
    instance.clientSecret = 'YOUR_GOOGLE_SIGN_IN_OAUTH_CLIENT_SECRET';
    instance.tokenDataStore = GoogleSignInDesktopTokenDataStore();
  }

  runApp(
    const MaterialApp(
      home: SignInDemo(),
      title: 'Google Sign In',
    ),
  );
}

class SignInDemo extends StatefulWidget {
  const SignInDemo({
    super.key,
  });

  @override
  State<SignInDemo> createState() {
    return _SignInDemoState();
  }
}

class _SignInDemoState extends State<SignInDemo> {
  GoogleSignInAccount? _currentUser;
  var _isAuthorized = false;
  String? _contactText;
  String? _errorMessage;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign In'),
      ),
      body: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (_currentUser case final currentUser?)
              ..._buildAuthenticatedWidgets(currentUser)
            else
              ..._buildUnauthenticatedWidgets(),
            if (_errorMessage case final errorMessage?) Text(errorMessage),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    unawaited(
      GoogleSignIn.instance.initialize(clientId: clientId).then(
        (_) {
          GoogleSignIn.instance.authenticationEvents
              .listen(_handleAuthenticationEvent)
              .onError(_handleAuthenticationError);

          GoogleSignIn.instance.attemptLightweightAuthentication();
        },
      ),
    );
  }

  List<Widget> _buildAuthenticatedWidgets(
    GoogleSignInAccount user,
  ) {
    return [
      ListTile(
        leading: GoogleUserCircleAvatar(
          identity: user,
        ),
        title: Text(user.displayName ?? ''),
        subtitle: Text(user.email),
      ),
      const Text('Signed in successfully.'),
      if (_isAuthorized) ...[
        if (_contactText case final contactText?) Text(contactText),
        ElevatedButton(
          child: const Text('Refresh'),
          onPressed: () => _handleGetContact(user),
        ),
      ] else ...[
        const Text('Authorization needed to read your contacts.'),
        ElevatedButton(
          onPressed: () => _handleAuthorizeScopes(user),
          child: const Text('Request permissions'),
        ),
      ],
      ElevatedButton(
        onPressed: _handleSignOut,
        child: const Text('Sign out'),
      ),
    ];
  }

  List<Widget> _buildUnauthenticatedWidgets() {
    return [
      const Text('You are not currently signed in.'),
      if (GoogleSignIn.instance.supportsAuthenticate())
        ElevatedButton(
          onPressed: () async {
            try {
              await GoogleSignIn.instance.authenticate();
            } catch (e) {
              _errorMessage = e.toString();
            }
          },
          child: const Text('Sign in'),
        )
      else
        const Text('This platform does not have a known authentication method'),
    ];
  }

  String _errorMessageFromSignInException(
    GoogleSignInException e,
  ) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in canceled',
      _ => 'GoogleSignInException ${e.code}: ${e.description}',
    };
  }

  Future<void> _handleAuthenticationError(
    Object e,
  ) async {
    setState(() {
      _currentUser = null;
      _isAuthorized = false;
      _errorMessage = e is GoogleSignInException
          ? _errorMessageFromSignInException(e)
          : 'Unknown error: $e';
    });
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    final authorization =
        await user?.authorizationClient.authorizationForScopes(scopes);

    setState(() {
      _currentUser = user;
      _isAuthorized = authorization != null;
      _errorMessage = null;
    });

    if (user != null && authorization != null) {
      unawaited(_handleGetContact(user));
    }
  }

  Future<void> _handleAuthorizeScopes(
    GoogleSignInAccount user,
  ) async {
    try {
      await user.authorizationClient.authorizeScopes(scopes);

      setState(() {
        _isAuthorized = true;
        _errorMessage = null;
      });

      unawaited(_handleGetContact(_currentUser!));
    } on GoogleSignInException catch (e) {
      _errorMessage = _errorMessageFromSignInException(e);
    }
  }

  Future<void> _handleGetContact(
    GoogleSignInAccount user,
  ) async {
    setState(() {
      _contactText = 'Loading contact info...';
    });

    final headers = await user.authorizationClient.authorizationHeaders(scopes);

    if (headers == null) {
      setState(() {
        _contactText = null;
        _errorMessage = 'Failed to construct authorization headers.';
      });

      return;
    }

    final response = await get(
      Uri.https(
        'people.googleapis.com',
        '/v1/people/me/connections',
        {
          'requestMask.includeField': 'person.names',
        },
      ),
      headers: headers,
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _isAuthorized = false;
          _errorMessage =
              'People API gave a ${response.statusCode} response. Please re-authorize access.';
        });
      } else {
        setState(() {
          _contactText =
              'People API gave a ${response.statusCode} response. Check logs for details.';
        });
      }

      return;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final namedContact = _pickFirstNamedContact(data);

    setState(() {
      if (namedContact != null) {
        _contactText = 'I see you know $namedContact!';
      } else {
        _contactText = 'No contacts to display.';
      }
    });
  }

  Future<void> _handleSignOut() async {
    await GoogleSignIn.instance.disconnect();
  }

  String? _pickFirstNamedContact(
    Map<String, dynamic> data,
  ) {
    final connections = data['connections'] as List<dynamic>?;

    final contact = connections?.firstWhere(
      (contact) => (contact as Map<Object?, dynamic>)['names'] != null,
      orElse: () => null,
    ) as Map<String, dynamic>?;

    if (contact != null) {
      final names = contact['names'] as List<dynamic>;

      final name = names.firstWhere(
        (name) => (name as Map<Object?, dynamic>)['displayName'] != null,
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (name != null) {
        return name['displayName'] as String?;
      }
    }

    return null;
  }
}

class GoogleSignInDesktopTokenDataStore
    implements GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> {
  // TODO: Store tokens in a secure location that is accessible between sessions.
  GoogleSignInDesktopTokenData? _value;

  @override
  Future<GoogleSignInDesktopTokenData?> get() async {
    // TODO: Store tokens in a secure location that is accessible between sessions.
    return _value;
  }

  @override
  Future<void> set(GoogleSignInDesktopTokenData? value) async {
    // TODO: Store tokens in a secure location that is accessible between sessions.
    _value = value;
  }
}
