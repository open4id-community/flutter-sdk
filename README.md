# open4id_sdk

Open4ID client sdk for Flutter. v1 ships Android only;
iOS is a `platform_unavailable` stub until the Swift native SDK
(`sdks/ios/`) lands.

## Status

**Approved 2026-10-16.** v1 ships Android-only. iOS support is deferred.

## Installation

```yaml
dependencies:
  open4id_sdk: ^0.3.2
```

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

The Flutter plugin (`Open4idSdkPlugin`) implements `ActivityAware` and
forwards `onActivityResult` to `SocialAuthClient.completeGoogleSignIn()` for
the Google account picker result.

## Platform strategy

- Dart owns the public API and error mapping (`client.auth.*` / `system.*`).
- Android platform side delegates to `sdks/android/open4id-sdk/` (Java,
  version `0.3.2`) via platform channels.
- The Flutter plugin (`Open4idSdkPlugin`) implements `ActivityAware` and
  forwards Google sign-in `onActivityResult` results to
  `SocialAuthClient.completeGoogleSignIn()`; host `MainActivity` should also
  forward `onNewIntent` URLs to `auth.handleNewIntent()` for GitHub/Apple
  callbacks.
- iOS platform side returns `platform_unavailable` for every method in v1.

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
flutter pub get        # pending: Flutter not installed in this environment
flutter analyze        # pending: Flutter not installed in this environment
flutter test           # pending: Flutter not installed in this environment
```

Live smoke on Android emulator + real device: bootstrap, redirect sign-in,
password/guest/social, refresh rotation, revoke, delete.

All Markdown in English.