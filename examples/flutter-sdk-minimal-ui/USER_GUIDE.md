# Open4ID Flutter SDK — User Guide

Welcome to the Open4ID Flutter SDK (`open4id_sdk`), the Flutter authentication
SDK for Open4ID player identity in mobile games and apps. One Dart API drives
both platforms: Android delegates to the native Java SDK, iOS delegates to the
native Swift SDK. This guide walks producers through installation, per-platform
setup, configuration, sign-in, and the operational details needed to ship to
Google Play and the App Store.

For a condensed reference, see [README.md](README.md).

**At a glance:**

- OAuth 2.0 Authorization Code + PKCE (S256) against the Open4ID
  authorization server — no web views you own, no OAuth secrets in the app.
- Opaque, server-validated tokens; the SDK never parses or trusts a JWT
  locally.
- Full API parity with the Open4ID JavaScript (`@open4id/sdk`), Android
  (`com.open4id:open4id-sdk`), and iOS (`Open4IDSDK`) SDKs — every method
  delegates to the platform-native client through platform channels, so
  per-platform behavior always matches the native SDK.
- Google sign-in works on both platforms: Google Play Services on Android,
  the interactive GoogleSignIn-iOS sheet on iOS.
- Optional prebuilt login UI: a full-page view and a modal dialog widget with
  English/Vietnamese localization.

## Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Android project setup](#android-project-setup)
4. [iOS project setup](#ios-project-setup)
5. [Configure the client](#configure-the-client)
6. [Sign players in](#sign-players-in)
7. [Login UI (built-in widgets)](#login-ui-built-in-widgets)
8. [Social providers](#social-providers)
9. [Session management](#session-management)
10. [Player account flows](#player-account-flows)
11. [Delegate verification to your server (server callback)](#delegate-verification-to-your-server-server-callback)
12. [Device attestation](#device-attestation)
13. [Error handling](#error-handling)
14. [Token storage](#token-storage)
15. [Security model](#security-model)
16. [Troubleshooting](#troubleshooting)

## Requirements

| Item | Requirement |
|------|-------------|
| Dart SDK | 3.0.0 or newer |
| Flutter | 3.16.0 or newer |
| Android | minSdk 26 (Android 8.0); Google Play Services device for the Google flow |
| iOS | iOS 16.0+ deployment target; Swift Package Manager enabled in the host project |

## Installation

Add the package from [pub.dev](https://pub.dev/packages/open4id_sdk):

```yaml
dependencies:
  open4id_sdk: ^0.3.4
```

```sh
flutter pub get
```

The package delegates each platform to its native SDK, resolved automatically
at build time:

- **Android** — `com.open4id:open4id-sdk:0.3.3` from Maven Central (the plugin
  declares it; no host action needed) plus the platform channel plugin
  `com.open4id.sdk.flutter.Open4idSdkPlugin`.
- **iOS** — the native Swift SDK (`Open4IDSDK`, tag `v0.3.x`) resolved through
  the plugin's Swift Package manifest, plus the `GoogleSignIn-iOS` dependency
  used by the Google seam.

## Android project setup

Before configuring the client, your Android host needs three pieces of wiring:

1. **Deep-link intent filter.** Your `MainActivity` receives the redirect for
   GitHub/Apple social flows as a `VIEW` intent. Register the redirect URI's
   scheme in `AndroidManifest.xml`, exactly matching the redirect URI
   registered in the Open4ID console:

   ```xml
   <activity android:name=".MainActivity" ... >
     <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <!-- scheme/host/path must character-match your redirect URI -->
       <data android:scheme="com.example.game"
             android:host="open4id"
             android:pathPrefix="/callback" />
     </intent-filter>
   </activity>
   ```

2. **Google Play Services runtime dependency.** `play-services-auth` is
   `compileOnly` in the plugin's Android library so it never forces the
   dependency on host apps that do not use Google sign-in. Host apps that do
   use it add it as an `implementation` in
   `android/app/build.gradle.kts`:

   ```kotlin
   dependencies {
       implementation 'com.google.android.gms:play-services-auth:21.2.0'
   }
   ```

3. **Forward activity results and deep links.** The plugin owns the pending
   transaction state; your `MainActivity` forwards the two OS callbacks that
   carry sign-in results into it:

   ```kotlin
   import android.content.Intent
   import io.flutter.embedding.android.FlutterActivity

   class MainActivity : FlutterActivity() {
       override fun onNewIntent(intent: Intent) {
           super.onNewIntent(intent)
           // GitHub/Apple Custom Tab deep links (?code&state).
           if (intent.data != null) {
               com.open4id.sdk.flutter.SocialAuthClient.completeDeepLink(intent.data)
           }
       }

       override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
           super.onActivityResult(requestCode, resultCode, data)
           // Google account-picker result delivery.
           if (data != null) {
               com.open4id.sdk.flutter.SocialAuthClient.completeGoogleSignIn(requestCode, data)
           }
       }
   }
   ```

## iOS project setup

1. **Enable Swift Package Manager** for the Flutter host, once:

   ```sh
   flutter config --enable-swift-package-manager
   ```

   Then run `flutter pub get` / `flutter run` once so Flutter migrates the
   Xcode project. The plugin's Swift Package manifest
   (`ios/open4id_sdk/Package.swift`) resolves the native `Open4IDSDK` and
   `GoogleSignIn-iOS` automatically — no host dependency edits needed.
   CocoaPods does not support this plugin's iOS side (the podspec fails fast
   with instructions) — the native SDK ships via SPM only.

2. **Deployment target.** Set the iOS deployment target of your host Runner to
   **16.0** or newer (matching the native SDK).

3. **Register both URL schemes** in `ios/Runner/Info.plist` — the Open4ID
   redirect scheme (must character-match the redirect URI registered in the
   Open4ID console; the example below registers bundle id
   `com.example.game` as the scheme) and, for Google, the reversed GCP
   iOS-type client id:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLName</key>
       <string>com.example.game</string>
       <key>CFBundleURLSchemes</key>
       <array><string>com.example.game</string></array>
     </dict>
     <dict>
       <key>CFBundleURLName</key>
       <string>Google Sign In</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.<ios-client-id></string>
       </array>
     </dict>
   </array>
   ```

   No `Info.plist` keys are needed for GitHub/Apple — they use
   `ASWebAuthenticationSession`, which the SDK drives in-app.

## Configure the client

Create exactly one `Open4IDAuthClient` per app (the plugin scopes the native
client behind it) and configure it early, e.g. in your root widget's
`initState`:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

final auth = Open4IDAuthClient();

await auth.configure(
  appId: 'app_9f3ab2c1',
  environment: 'production',                 // development | sandbox | production
  publicSdkKey: 'sdk_pk_xV7...',             // public by design; never a secret
  redirectUri: 'com.example.game://open4id/callback',
  packageName: 'com.example.game',
);
```

The `redirectUri` and `packageName` usually carry the same string on both
platforms (a custom scheme bound to your app identity), but they must be the
values registered **for that platform** in the Open4ID console — the
application registration holds one native binding per platform.

Parameters:

| Parameter | Notes |
|-----------|-------|
| `appId` | Your app's identifier (`app_` prefix), from the Open4ID console. |
| `environment` | `production` for store builds, `sandbox` for pre-release testing, `development` for local integration. |
| `publicSdkKey` | Public by design (`sdk_pk_…`); safe to embed. Never embed a secret key (`sdk_sk_…`). |
| `endpoint` | Optional override; leave the default `https://id.open4id.com/api`. A custom endpoint is invalid in `production`. |
| `redirectUri` | Exact-match custom scheme registered for the app; `https` required in `production`. |
| `scope` | Optional, default `openid profile email`; your value must include `openid`. |
| `packageName` | The platform's registered native binding — bundle id on iOS, package name on Android. |
| `portalOrigin` | Optional override of the Portal origin hosting the per-provider social bridges; leave for production. |
| `googleIosClientId` | **iOS only.** The GCP *iOS-type* OAuth client id bound to your bundle. Needed for `signInWithGoogle()` on iOS; omitted/empty keeps Google reporting `client.auth.provider_unavailable`. Ignored on Android, which binds through its package name + SHA-1. |

Re-running `configure` reconfigures the same client in place and clears any
loaded session (matching native semantics).

## Sign players in

1. **Bootstrap** — performs the native application handshake
   (`platform: "android"` / `"ios"` + your native binding). It fetches app
   metadata, provider availability, and login readiness, and drives the
   provider buttons in the SDK's login UI. Re-run it on each app launch.

2. **Pick a flow** — password, guest, social, or built-in login UI.

3. **Manage the session** — read state, refresh, sign out.

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// Subscribe to session transitions from any source.
final unsubscribe = auth.onAuthStateChanged((session, user) {
  if (session != null) {
    print('signed in: ${session.userId} ${user?.email ?? '(no email)'}');
  } else {
    print('signed out');
  }
});

try {
  // 1. Bootstrap (required once per launch before using flows/UI).
  final bootstrap = await auth.bootstrap();
  print('app: ${bootstrap.displayName ?? '(no name)'} '
      'google=${bootstrap.login.google.enabled}');

  // 2. Sign in.
  // (a) Email + password.
  final session1 = await auth.signInWithPassword(
      'player@example.com', 'correct-horse');
  final user = await auth.getUser();
  print('signed in as ${user.email ?? '(no email)'} (${session1.userId})');

  // (b) Or a guest session (anonymous account; upgradeable later).
  final session2 = await auth.continueAsGuest();

  // 3. Session lifecycle.
  print(auth.getSession()?.userId);        // current session or null
  print(auth.getCachedUser()?.email);      // last user info
  print(auth.isAuthenticated());           // true while the token is fresh
  await auth.refresh();                    // rotates the token; single-flight
  await auth.ensureSession(60000);         // refresh only if within 60 s of expiry
  await auth.signOut();                    // revokes server-side, clears locally
} on SdkError catch (e) {
  // Stable keys and numeric codes — see [Error handling](#error-handling).
  print('auth error: $e');
}

// later: unsubscribe();
```

**Non-persisted sessions:** the session lives for the client instance's
process lifetime only (see [Token storage](#token-storage)) — players sign in
once per app launch, while the session stays fully usable (with
`ensureSession`-driven refresh) for the entire run.

Error mapping note: the Dart mapper re-hydrates native errors into the typed
classes below, so identical `catch (e) { }` code works on both platforms.

## Login UI (built-in widgets)

The SDK ships two ready-made widgets so you do not have to build login screens
yourself: **`showOpen4IDAuthView`** (full-page route: email/password, sign-up,
forgot-password, guest, provider buttons, email verification, session account
view, account deletion) and **`showOpen4IDLoginDialog`** (center-screen modal
on a dimmed, tap-outside-dismissable backdrop). Both are localized in English
(`en`) and Vietnamese (`vi`); each renders the provider list from the
`Bootstrap` snapshot you pass — provider buttons render only for providers
that bootstrap reports as enabled.

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// After configure + bootstrap succeeded:
await showOpen4IDLoginDialog(
  context,
  auth,            // the configured client
  bootstrap,       // last snapshot from auth.bootstrap()
  locale: 'en',    // 'en' or 'vi'
  listener: (event) {
    // event: 'email_password' | 'guest' | 'google' | 'github' | 'apple'
    //        'signed_out' | 'account_deleted' | 'session' (re-rendered
    //        an already-signed-in state)
    print('login happened: $event');
  },
);
```

Or the full-page view:

```dart
await showOpen4IDAuthView(
  context,
  auth,
  bootstrap,
  locale: 'en',
  appName: 'My Game',        // overrides bootstrap displayName in the header
  listener: (event) => print('login happened: $event'),
);
```

Both widgets close themselves after the flow they were opened for completes
(sign-in/sign-up/guest, and account deletion), and re-render to the login form
on sign-out; `onAuthStateChanged` on the client keeps any host UI around them
in sync. When provider availability changes (e.g. you enabled Google in the
console mid-session), re-open the widget after another `auth.bootstrap()` so
its provider buttons reflect the fresh snapshot.

While the signed-in account view is showing, it exposes refresh, sign out, and
delete account directly — the same operations as the headless methods.

## Social providers

Every provider is implemented by the platform-native SDK through the same
channel surface; the plugin supplies the activity on Android and the
presentation anchor on iOS automatically. State/nonce generation and the code
exchange are SDK-owned.

### Google

- **Android** — Google Play Services: the plugin presents the account picker
  and requests a **fresh server auth code** whose audience is the Web client
  from `bootstrap().auth`/`login`. Sign-outs are best-effort before each
  interactive sign-in so the picker always appears.
- **iOS** — the plugin overrides the native SDK's Google code seam with the
  interactive **GoogleSignIn-iOS** sheet: the pre-configured
  `googleIosClientId` identifies the GCP iOS-type OAuth client and
  `serverClientID` is the Web client from bootstrap; the same
  fresh-server-auth-code rule applies.

```dart
try {
  final session = await auth.signInWithGoogle();
  print('google session: ${session.userId}');
} on SdkAuthError catch (e) {
  // user closed the picker → client.auth.popup_closed
  // interaction budget (120 s) expired → client.auth.popup_timeout
  // provider consent denied / other failure → client.auth.access_denied
  print('google failed: ${e.message}');
}
```

**Simulator note (iOS):** GoogleSignIn's keychain handshake cannot complete on
iOS simulators; the Google button surfaces a typed
`client.auth.access_denied` with `gid_*` diagnostics there. Verify the full
Google round-trip on a physical device (GitHub/Apple and all other flows are
unaffected on the simulator).

### GitHub and Apple

`signInWithGitHub()` (scopes `read:user user:email`) and `signInWithApple()`
(`scope=email`, `response_mode=form_post`, `nonce` doubling as state) open the
Open4ID Portal bridges — Custom Tabs on Android, `ASWebAuthenticationSession`
on iOS — and return control to your app through the redirect scheme; the SDK
exchanges the return code automatically.

```dart
await auth.signInWithGitHub();                    // default game callback URI
await auth.signInWithGitHub(
    callbackUri: 'com.example.game://open4id/callback'); // optional override
await auth.signInWithApple();                     // default Return URL
```

Timeout (120 s) maps to `client.auth.popup_timeout`; user cancellation to
`popup_closed`.

**Deep links:** register the scheme per platform (both setup sections above).
On Android, forwarded `onNewIntent` completes the flow. If your app receives
an OAuth callback URL by any other route (e.g. an interrupted flow that kept
the browser alive), pass it to the same completion path explicitly:

```dart
final handled = await auth.handleNewIntent(callbackUrl);
// true when a pending transaction could be completed from this URL
```

## Session management

### Observing state

`onAuthStateChanged` fires on every session transition (sign-in, sign-out,
refresh, email verification, account deletion) initiated through this client —
across all sources including the built-in login UI. The unregister callback
cancels the listener:

```dart
final unsubscribe = auth.onAuthStateChanged((session, user) { ... });
// later:
unsubscribe();
```

### Refresh and validity

- `isAuthenticated()` checks token freshness locally (with a 30 s expiry
  skew) — useful for gating UI.
- `refresh()` rotates the token; concurrent callers coalesce into a single
  flight while one is in progress.
- `ensureSession(minValidityMs)` refreshes only when the token is inside the
  validity window; call it before routing a player into gameplay.

If the refresh token has been invalidated elsewhere (used by another client,
or revoked at sign-out), the refresh fails and the local session is cleared —
never a partially swapped state. Catch `client.auth.not_authenticated` and
route the player back to sign-in.

## Player account flows

Beyond sign-in, the SDK covers the complete account surface:

| Method | Purpose |
|--------|---------|
| `register(email, password)` | Create a new player account. |
| `resendVerification(email)` | Re-send the email-verification message. |
| `verifyEmail(token)` | Complete email verification (`token` comes from the verification link). |
| `requestPasswordReset(email)` | Send a password-reset email. |
| `resetPassword(token, newPassword)` | Finish the reset using the emailed token. |
| `linkEmail(email, password)` | Attach an email/password identity to the **current guest** session and sign in with it. |
| `deleteAccount()` | Permanently delete the signed-in account (confirm before calling; irreversible). |
| `getUser()` | Fetch `/userinfo` claims for the current access token. |

Guest sessions become real accounts through `linkEmail`; regular accounts
already own their email.

## Delegate verification to your server (server callback)

For games where sensitive entitlements (purchases, bans, leaderboards) are
verified by your own backend, the SDK can deliver a signed receipt of a
**fresh sign-in** to that server automatically. The behavior is driven by the
bootstrap snapshot: only when your app has the server callback **enabled**
(as configured in the Open4ID console) do fresh sign-ins trigger best-effort
delivery of a `ServerCallbackReceipt` (bearer access token, expiry, scope, and
user claims — never a refresh token, verifier, or authorization code). When
disabled, nothing happens.

To opt in manually (e.g. re-delivering after a failed attempt):

```dart
try {
  await auth.notifyServer();
} on SdkError catch (e) {
  // `client.auth.server_callback_disabled` when the toggle is off;
  // otherwise transport errors — the session itself is unaffected.
}
```

Best-effort means a delivery failure never invalidates the session.

## Device attestation

`Attestation.collect()` returns an audit-only verdict envelope (Play Integrity
on Android, App Attest/DeviceCheck on iOS). In this release it is never
blocking: absence or failure never gates bootstrap or auth flows, and the
verdict reports `unavailable` on emulators/simulators or when attestation is
not yet contracted for your app. Treat it as telemetry, not as an entitlement
gate.

```dart
final verdict = await Attestation.collect();
print(verdict.platform, verdict.status, verdict.error ?? '(no error)');
```

## Error handling

The SDK exposes a typed error hierarchy with **stable keys and integer
codes**. Never branch on the message text — strings are human-readable and can
change between minor versions:

| Dart type | Code | Meaning |
|-----------|------|---------|
| `SdkValidationError` | `100003` | Request-shape validation failure; `fieldErrors` maps the unsafe fields (e.g. `appId`, `redirectUri`). |
| `SdkAuthError` | `110003` | Invalid credentials (`110005`), email verification required (`120001`), token failures. |
| `SdkRateLimitedError` | `150001` | Rate limit; carries `retryAfterSec` (`-1` when the server did not specify). |
| `SdkUnavailableError` | `160001` | Core API or transport unavailable (timeout, HTTP 5xx, connectivity). |
| `SdkInternalError` | `170001` | Unexpected internal failure. |
| `SdkNotImplementedError` | `-1` | Method not supported on the current platform or not yet shipped. |

Stable error keys mirror the sibling SDKs, e.g. `client.auth.not_authenticated`,
`client.auth.invalid_request`, `client.auth.provider_unavailable`,
`client.auth.popup_closed`, `client.auth.popup_timeout`, `client.auth.access_denied`,
`client.auth.server_callback_disabled`, `system.*`, `sdk.*` (e.g.
`sdk.not_initialized`, `sdk.not_implemented`).

All platform errors arrive as `PlatformException` and are re-thrown as the
typed classes above; `fieldErrors` and `retryAfterSec` are carried through
unchanged, so error handling code is identical on Android and iOS.

## Token storage

| Backend | Default | Notes |
|---------|---------|-------|
| In-memory | yes | Session lives for the client instance's process lifetime; lost on app close. |
| Platform encrypted store | reserved | `SessionStore` and `EncryptedSessionStore` (EncryptedSharedPreferences/Keystore on Android, Keychain on iOS) exist in the API for a persistence integration; in this release the plugin keeps sessions memory-only and the adapters are not yet bridged. |

Practical consequence for this release: **players re-authenticate once per app
launch** unless your server flows tolerate it (a short-lived gameplay session
per launch is not affected — the session is fully usable for the whole run;
`ensureSession(minValidityMs)` keeps it fresh during play).

Tokens are never written to `SharedPreferences`/`UserDefaults` by the SDK and
never logged — session and configuration descriptions redact token values, and
the SDK key is always truncated to its last four characters.

## Security model

- **No secrets in the SDK.** `sdk_sk_...`, OAuth client secrets, Apple private
  keys, and Vault references never enter the client. The `sdk_pk_...` key is
  public by design.
- **No local JWT validation.** Player tokens are opaque and validated
  server-side. The SDK never parses a JWT nor exchanges JWKS material.
- **Exact-match redirect URIs.** Native redirect URIs are custom schemes
  registered per platform (`com.example.game://open4id/callback`); the Portal
  bridges only open the exact registered scheme and native binding.
- **No WebView authentication.** All hosted flows use Custom Tabs (Android) or
  `ASWebAuthenticationSession` (iOS) — never a web view you own.

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|-------------------|
| `SdkValidationError` with `fieldErrors["appId"]` or `["publicSdkKey"]` | Values do not match the `app_…` / `sdk_pk_…` shapes — check for copy-paste truncation. |
| `SdkValidationError` with `fieldErrors["redirectUri"]` | The redirect URI is not exact-registered (character-for-character) for the current platform, or the scheme is not registered in the manifest / `Info.plist`. |
| `sdk.not_initialized` | `configure` did not complete successfully (or was never called) before another method ran. |
| `client.auth.not_authenticated` | The session expired or was cleared; use `ensureSession(minValidityMs)` before gameplay. |
| `sdk.not_implemented` on a platform method | The method is not supported on that platform in this SDK version. |
| `client.auth.provider_unavailable` from `signInWithGoogle` on Android | Play Services unavailable on the device/emulator, or the SHA-1/package binding of the debug/release build is not registered in the Google console for this app. |
| `client.auth.provider_unavailable` from `signInWithGoogle` on iOS | `googleIosClientId` was not supplied (or is empty) at `configure`; supply the GCP iOS-type client id and the reversed scheme in `Info.plist`. |
| Google fails on the iOS simulator with `access_denied` and `gid_*` diagnostics | Expected — GoogleSignIn's keychain handshake cannot complete on iOS simulators; verify on a physical device. |
| `client.auth.popup_timeout` from GitHub/Apple | The redirect scheme is not registered (Android manifest / iOS URL Types), or the sign-in browser was dismissed/blocked; re-register and call again. |
| GitHub/Apple callback arrives but the flow does not complete on Android | The host `MainActivity` does not forward `onNewIntent` to `SocialAuthClient.completeDeepLink(...)` (see [Android project setup](#android-project-setup)). |
| `SdkRateLimitedError` (`150001`) | Rate limit hit; honor `retryAfterSec` before retrying the same request. |
| Session gone after app restart | In-memory storage — see [Token storage](#token-storage). |
