import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_desktop/google_sign_in_desktop.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart';

const scopes = [
  'email',
  'https://www.googleapis.com/auth/contacts.readonly',
];

final _googleSignIn = GoogleSignIn(
  clientId: 'YOUR_GOOGLE_SIGN_IN_OAUTH_CLIENT_ID.apps.googleusercontent.com',
  scopes: scopes,
);

void main() {
  if (GoogleSignInPlatform.instance case GoogleSignInDesktop instance) {
    instance.clientSecret = 'YOUR_GOOGLE_SIGN_IN_OAUTH_CLIENT_SECRET';
    instance.tokenDataStore = GoogleSignInDesktopTokenDataStore();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
      title: 'Google Sign In',
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  GoogleSignInAccount? _currentUser;
  String _contactText = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign In'),
      ),
      body: _buildBody(),
    );
  }

  @override
  void initState() {
    super.initState();

    _googleSignIn.onCurrentUserChanged.listen((currentUser) async {
      setState(() {
        _currentUser = currentUser;
      });

      if (currentUser != null) {
        unawaited(_handleGetContact(currentUser));
      }
    });

    _googleSignIn.signInSilently();
  }

  Widget _buildBody() {
    if (_currentUser case final currentUser?) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ListTile(
            leading: GoogleUserCircleAvatar(
              identity: currentUser,
            ),
            title: Text(currentUser.displayName ?? ''),
            subtitle: Text(currentUser.email),
          ),
          const Text('Signed in successfully.'),
          Text(_contactText),
          ElevatedButton(
            onPressed: () => _handleGetContact(currentUser),
            child: const Text('REFRESH'),
          ),
          ElevatedButton(
            onPressed: _handleSignOut,
            child: const Text('SIGN OUT'),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Text('You are not currently signed in.'),
          ElevatedButton(
            onPressed: _handleSignIn,
            child: const Text('SIGN IN'),
          ),
        ],
      );
    }
  }

  Future<void> _handleGetContact(GoogleSignInAccount user) async {
    setState(() {
      _contactText = 'Loading contact info...';
    });

    final response = await get(
      Uri.https(
        'people.googleapis.com',
        '/v1/people/me/connections',
        {
          'requestMask.includeField': 'person.names',
        },
      ),
      headers: await user.authHeaders,
    );

    if (response.statusCode != 200) {
      setState(() {
        _contactText = 'People API gave a ${response.statusCode} response.';
      });

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

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      print(e);
    }
  }

  String? _pickFirstNamedContact(Map<String, dynamic> data) {
    final connections = data['connections'] as List<dynamic>?;

    final contact = connections?.firstWhere(
      (contact) {
        return (contact as Map<Object?, dynamic>)['names'] != null;
      },
      orElse: () => null,
    ) as Map<String, dynamic>?;

    if (contact != null) {
      final names = contact['names'] as List<dynamic>;

      final name = names.firstWhere(
        (name) {
          return (name as Map<Object?, dynamic>)['displayName'] != null;
        },
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
