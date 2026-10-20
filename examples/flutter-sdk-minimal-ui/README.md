# open4id_sdk

Open4ID client sdk for Flutter. Android delegates to the native Java SDK
(`com.open4id:open4id-sdk`); iOS delegates to the native Swift SDK
(`Open4IDSDK`), resolved through the plugin's Swift Package Manager
manifest. One Dart API for both platforms.

## Status

**Approved 2026-10-16.** v1 shipped Android-only (iOS was a
`platform_unavailable` stub). **iOS support is now implemented** on top of
the `ios-v0.3.3` native tag: same method surface, same wire maps. Provides
`signInWithPassword`, `continueAsGuest`, `signInWithGitHub`, `signInWithApple`,
and `signInWithGoogle` (interactive GoogleSignIn-iOS picker, supplied by the
plugin's `Open4IDSocialClient` — enable it per app with
`configure(googleIosClientId: ...)`). `ensureSession` maps to
`ensureSession(minValidityMs)`.

## Installation

```yaml
dependencies:
  open4id_sdk: ^0.3.4
```

### iOS host requirements

- iOS 16.0+ deployment target.
- Build with **Swift Package Manager** for iOS: enable
  `flutter config --enable-swift-package-manager` and migrate the host
  project (see flutter SPM doc: `flutter run` after `flutter pub get`; the
  plugin resolves `Open4IDSDK` from
  `https://github.com/open4id-community/ios-sdk`, tag `v0.3.x`, via
  `ios/open4id_sdk/Package.swift`). CocoaPods is not supported for the iOS
  side — the podspec intentionally fails fast with the reason.
- Google sign-in works out of the box once you configure it:
  - Pass the GCP **iOS-type** OAuth client id to `configure(googleIosClientId:)`
    (ignored on Android, which binds via package name + SHA-1). Empty/omitted
    keeps the typed `provider_unavailable` behavior on the Google button.
  - Add the reversed client id (`com.googleusercontent.apps.<client-id>`) as
    a URL scheme in the host `Info.plist` (plus your `redirectUri` scheme).
  - The GoogleSignIn-iOS SDK itself is resolved automatically by the plugin's
    Swift Package manifest — no host dependency needed.

Or depend on the local plugin:

```yaml
dependencies:
  open4id_sdk:
    path: ../sdks/flutter/open4id_sdk
```

## API

See `lib/open4id_sdk.dart` and `lib/src/open4id_auth_client.dart`. The Dart
API mirrors `@open4id/sdk` and the Android native SDK:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

final auth = Open4IDAuthClient();

await auth.configure(
  appId: 'app_...',
  environment: 'development',
  publicSdkKey: 'sdk_pk_...',
  redirectUri: 'com.example.game://open4id/callback',
  packageName: 'com.example.game',
);

final boot = await auth.bootstrap();
final session = await auth.signInWithPassword('player@example.com', 'password');
final user = await auth.getUser();
await auth.refresh();
await auth.signOut();
```

## Login dialog (UI widget)

The SDK ships `Open4IDLoginDialog` — a modal dialog that mirrors the native
Android `Open4IDLoginDialog`:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// After configure + bootstrap:
showOpen4IDLoginDialog(
  context,
  auth,
  bootstrap,
  locale: 'en',
  appName: 'My Game',          // optional; falls back to bootstrap.displayName
  listener: (provider) {
    print('signed in via $provider');
  },
);
```

The dialog renders email/password, sign-up ("Create account"), forgot-password,
guest, and social buttons (Google, GitHub, Apple) per bootstrap readiness, in
the same order as the Android SDK (social first, then email/password). The
dialog auto-dismisses on successful sign-in/sign-up/guest. It listens to
`onAuthStateChanged` so it reflects sign-in/sign-out/deletion from any source —
the host app reacts via the `listener` callback rather than in-dialog status
toasts.

## Login view (UI widget)

The SDK ships `Open4IDAuthView` — a full-screen login view that mirrors the
native Android `Open4IDAuthView`:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// After configure + bootstrap:
showOpen4IDAuthView(
  context,
  auth,
  bootstrap,
  locale: 'en',
  appName: 'My Game',
  listener: (provider) {
    print('signed in via $provider');
  },
);
```

The view renders email/password, sign-up ("Create account"), forgot-password
("Send reset link"), guest, link-email ("Link email"), delete-account
("Delete my account"), and social buttons (Google, GitHub, Apple) per bootstrap
readiness. While the bound client holds a session, it renders the signed-in
account view (refresh, sign out, delete account) instead of the login form.
Action buttons (Sign in, Continue as guest, Sign up, Send reset link, Link
email, Delete my account, Refresh, Sign out, Delete account, BACK) render
without icons; only social provider buttons carry brand SVG icons (Google,
GitHub, Apple). It listens to `onAuthStateChanged` so it reflects state
changes from any source.

## Deep-link callback forwarding

### Android

GitHub/Apple Custom Tab callbacks return via a deep-link intent
(`?code&state`) on `onNewIntent`. The host app's `MainActivity` should forward
the intent URL to the SDK:

```dart
// In your MainActivity or equivalent:
import 'package:open4id_sdk/open4id_sdk.dart';

final auth = Open4IDAuthClient();

// Forward onNewIntent URL:
await auth.handleNewIntent(intentDataString);
```

### iOS

GitHub/Apple callbacks complete inside the SDK's `ASWebAuthenticationSession`
(the plugin attaches the foreground key window as the presentation anchor).
Deep-link forwarding is not required for the standard flows; when a callback
URL is forwarded to your app anyway (e.g. an interrupted flow that kept the
system browser alive), pass it to `auth.handleNewIntent(...)` and the same
completion is attempted — the method returns whether a pending transaction
was consumable.

The Flutter plugin (`Open4idSdkPlugin`) implements `ActivityAware` on Android
and forwards `onActivityResult` to `SocialAuthClient.completeGoogleSignIn()`
for the Google account picker result. GitHub/Apple callbacks are handled by
the base SDK on both platforms; `handleNewIntent` completes the parked code
slot when a deep link actually reaches the app.

## Platform strategy

- Dart owns the public API and error mapping (`client.auth.*` / `system.*`).
- Android platform side delegates to `sdks/android/open4id-sdk/` (Java,
  version `0.3.3`) via platform channels. GitHub/Apple Custom Tabs are
  implemented by the base SDK (`Open4IDAuthClient.openGitHubCustomTab` /
  `openAppleCustomTab`); pass the host `Activity` via
  `new Open4IDAuthClient(activity)` or `setHostActivity(activity)`.
- The Flutter plugin (`Open4idSdkPlugin`) implements `ActivityAware` on
  Android and forwards Google sign-in `onActivityResult` results to
  `SocialAuthClient.completeGoogleSignIn()`; host `MainActivity` should also
  forward `onNewIntent` URLs to `auth.handleNewIntent()` for GitHub/Apple
  callbacks.
- iOS platform side delegates to the native Swift SDK (`Open4IDSDK`
  v0.3.3) via platform channels — the same
  `Open4IDAuthClient` headless surface as Swift apps:
  `bootstrap()` (`platform: "ios"` binding), `handleCallback`/PKCE,
  single-flight refresh, server-callback receipt, `signOut` with best-effort
  revocation. Social providers:
  - Apple/GitHub: SDK-owned `ASWebAuthenticationSession` (plugin supplies
    the foreground key window as the presentation anchor).
  - Google: interactive GoogleSignIn-iOS picker implemented by the plugin's
    `Open4IDSocialClient` (subclass of the native client overriding
    `getGoogleAuthorizationCode`) — the iOS analogue of the Android
    `SocialAuthClient`. Client id arrives through
    `configure(googleIosClientId:)`; empty keeps the typed
    `provider_unavailable` behavior. Cancel maps to `popup_closed`,
    the interaction budget (120 s) to `popup_timeout`, other GID failures
    to `access_denied` with the `gid_*` diagnostics in `field_errors`.
    Note: simulators cannot complete the Google keychain handshake
    (`gid_code=-2` keychain error); verify on a physical device.
- Attestation stays audit-only on both platforms (Play Integrity stub on
  Android, `unavailable` verdict on iOS until the attestKey handshake is
  contracted).

## Security boundary

- Never stores `sdk_sk_...`, OAuth secrets, Apple private keys, Vault refs,
  or raw tokens in Dart. Tokens at rest use platform encrypted storage
  (opt-in); memory-only default.
- All errors branch on stable keys, never localized text.
- `play-services-auth` is `compileOnly` in the SDK AAR — the host app must
  add `implementation 'com.google.android.gms:play-services-auth:21.2.0'`
  as a runtime dependency for Google sign-in to work (see both example
  apps' `build.gradle.kts`).

## Verification

```sh
cd sdks/flutter/open4id_sdk
flutter pub get
flutter analyze
flutter test
```

iOS plugin verifier (scratch host app, matches the pass run for v0.3.3 +
iOS support):

```sh
cd /tmp && flutter create --platforms=ios --org com.open4id \
    --project-name open4id_scratch open4id_scratch && cd open4id_scratch
# - add `open4id_sdk: { path: /path/to/sdks/flutter/open4id_sdk }` to pubspec.yaml
# - bump IPHONEOS_DEPLOYMENT_TARGET to 16.0 in ios/Runner.xcodeproj
#   (FlutterGeneratedPluginSwiftPackage raises its SupportedPlatform to the
#    host project's deployment target; 16.0 matches the plugin + native SDK)
flutter pub get
flutter build ios --simulator --no-codesign   # resolves Open4IDSDK via SPM
```

Live smoke on Android emulator + real device: bootstrap, redirect sign-in,
password/guest/social, refresh rotation, revoke, delete. On iOS: password +
guest round-trips and the GitHub/Apple web sessions on a real device
(simulator web sheets can be flaky on iOS 27.1 per the native SDK task
records).

All Markdown in English.