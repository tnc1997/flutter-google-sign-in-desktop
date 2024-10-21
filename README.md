# google_sign_in_desktop

The desktop implementation of [`google_sign_in`](https://pub.dev/packages/google_sign_in). Please note that this implementation is not endorsed.

The desktop implementation uses the [Authorization Code Flow with Proof Key for Code Exchange (PKCE)](https://datatracker.ietf.org/doc/html/rfc7636) flow, with the [loopback address](https://developers.google.com/identity/protocols/oauth2/native-app#redirect-uri_loopback) as the `redirect_uri`, to get tokens.

## Getting Started

1. Add this package as a dependency because it is [not endorsed](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#non-endorsed-federated-plugin).

   ```yaml
   dependencies:
     google_sign_in: ^6.0.0
     google_sign_in_desktop: { git: https://github.com/tnc1997/flutter-google-sign-in-desktop.git }
     google_sign_in_platform_interface: ^2.0.0
   ```
2. Implement `GoogleSignInDesktopStore<GoogleSignInDesktopTokenData>` to store tokens between sessions.

   ```dart
   class GoogleSignInDesktopTokenDataStore implements GoogleSignInDesktopStore<GoogleSignInDesktopTokenData> {
     const GoogleSignInDesktopTokenDataStore();
   
     @override
     Future<GoogleSignInDesktopTokenData?> get() async {}

     @override
     Future<void> set(GoogleSignInDesktopTokenData? value) async {}
   }
   ```

   > Your application should store both tokens in a secure, long-lived location that is accessible between different invocations of your application. The refresh token enables your application to obtain a new access token if the one that you have expires. As such, if your application loses the refresh token, the user will need to repeat the OAuth 2.0 consent flow so that your application can obtain a new refresh token.

3. Follow the instructions [here](https://developers.google.com/identity/protocols/oauth2/native-app) to create a desktop OAuth client.
4. Update `main.dart` to initialize the plugin and set the required instance fields.

   ```dart
   const scopes = <String>[
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
       instance.tokenDataStore = const GoogleSignInDesktopTokenDataStore();
     }
   
     runApp(const MyApp());
   }
   ```

   > Installed apps are distributed to individual devices, and it is assumed that these apps cannot keep secrets. They can access Google APIs while the user is present at the app or when the app is running in the background. Incremental authorization with installed apps is not supported due to the fact that the client cannot keep the client_secret confidential.

5. Read the documentation [here](https://pub.dev/packages/google_sign_in) for more information on how to use `google_sign_in`.

## Compatibility

The desktop implementation implements the following methods:

| Method            |    |
|-------------------|----|
| `canAccessScopes` | ❌ |
| `clearAuthCache`  | ✔️ |
| `disconnect`      | ✔️ |
| `getTokens`       | ✔️ |
| `init`            | ✔️ |
| `isSignedIn`      | ✔️ |
| `requestScopes`   | ✔️ |
| `signIn`          | ✔️ |
| `signInSilently`  | ✔️ |
| `signOut`         | ✔️ |

## Dependencies

The desktop implementation depends on the following packages:

| Package        |                                                                                                                     |
|----------------|---------------------------------------------------------------------------------------------------------------------|
| `crypto`       | This package is required to create the code challenge, which is the SHA256 hash of the ASCII encoded code verifier. |
| `http`         | This package is required to send the token request, the userinfo request, and the revocation request.               |
| `url_launcher` | This package is required to launch the authorization url, which opens the browser and prompts the user to sign in.  |
