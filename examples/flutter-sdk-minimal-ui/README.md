# flutter_sdk_minimal_ui

Minimal Flutter example with a game-built UI on top of the `open4id_sdk` headless API.
Ports all features from the native `android-sdk-minimal-ui` example: editable config,
bootstrap, login UI with email/password, sign-up, guest, Google/GitHub/Apple social
sign-in, session management, `onAuthStateChanged` events, and the SDK's
`Open4IDLoginDialog` modal.

Uses `sdks/flutter/open4id_sdk` (Flutter plugin, Android v1) which delegates
to `sdks/android/open4id-sdk/` (Java, version 0.3.2) via platform channels.

## Prerequisites

1. An Open4ID application with a development environment, a public SDK
   key (`sdk_pk_...`), and email/password + guest login enabled
   (Publisher Portal → Applications → Authentication). The form comes
   prefilled with the dev `Login Show Case` values.
2. No dashboard changes needed: this example shares the package
   (`com.open4id.example.android`) and redirect URI
   (`com.open4id.example.android://open4id/callback`) already
   registered for the SDK sample app.
3. An Android device/emulator with Play Services and a signed-in Google
   account for the Google flow.

## Run

```sh
cd examples/flutter-sdk-minimal-ui
flutter pub get
flutter build apk --debug   # or flutter run
flutter install             # installs the debug APK
```

## Features

| Feature | Description |
|---------|-------------|
| **Config** | Editable app ID, environment, public key, endpoint, redirect URI, package name, portal origin |
| **Bootstrap** | Loads OAuth discovery + provider readiness from the dev Core API |
| **Auto-bootstrap** | "Open login UI" / "Open login dialog" auto-load bootstrap if not yet loaded |
| **Login UI** | Flutter-built full-page screen with email/password, sign-up, forgot-password, guest |
| **Login dialog** | SDK-provided `Open4IDLoginDialog` modal — same flows as the UI page |
| **Login view** | SDK-provided `Open4IDAuthView` full-page view with session-aware account view |
| **Google sign-in** | Interactive `GoogleSignInIntent` account picker (always returns a fresh server auth code) |
| **GitHub sign-in** | Custom Tab + deep-link callback via Portal bridge |
| **Apple sign-in** | Custom Tab with `form_post` + deep-link callback via Portal bridge |
| **Session** | Refresh, sign out, delete account, user info |
| **Auth state events** | `onAuthStateChanged` listener reacts to any sign-in/sign-out/refresh/deletion |
| **Locale** | English / Vietnamese switching |

## Social sign-in registration

Google/GitHub/Apple bridges need their own registration (provider consoles plus
the per-app Portal bridge URLs) — email and guest work with the dev
registration above.

- **GitHub / Apple** — implemented by the base SDK
  (`Open4IDAuthClient.openGitHubCustomTab` / `openAppleCustomTab`, plus
  `Open4IDAuthClient.completeDeepLink`). Pass the host `Activity` to the
  client (`new Open4IDAuthClient(activity)` or `setHostActivity(activity)`)
  and forward the deep-link intent URL to
  `auth.handleNewIntent(...)` so the SDK completes the callback.
- **Google** — the Flutter plugin's `SocialAuthClient`
  (`sdks/flutter/open4id_sdk/android/.../SocialAuthClient.java`) overrides
  the SDK's `getGoogleAuthorizationCode` seam with the interactive
  `GoogleSignInIntent` account picker (fixes the silent empty-code issue from
  the SDK default `AuthorizationClient` flow). Requires
  `play-services-auth` as a runtime dependency in the host app.

The host app's `AndroidManifest.xml` registers the deep-link intent filter for
`com.open4id.example.android://open4id/callback`, and
`MainActivity.kt` forwards `onActivityResult` (Google picker result) and
`onNewIntent` (GitHub/Apple deep links) to the SDK.

## Auth state events

The activity registers `client.onAuthStateChanged(...)` so the main app can
react to any auth state change (sign-in, sign-out, refresh, deletion) from any
source — headless calls, the login UI, or the login dialog.

## Runtime dependency note

The Flutter SDK declares `play-services-auth` as `compileOnly` (so it never
forces the dependency on host apps). Both example apps add it as
`implementation 'com.google.android.gms:play-services-auth:21.2.0'` in their
`android/app/build.gradle.kts` — required for Google sign-in to work.

## Using the SDK login dialog

The Flutter SDK now ships `Open4IDLoginDialog` (`showOpen4IDLoginDialog()`),
mirroring the native Android `Open4IDLoginDialog`:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// After configure + bootstrap:
showOpen4IDLoginDialog(
  context,
  authClient,
  bootstrap,
  locale: 'en',
  listener: (provider) {
    print('signed in via $provider');
  },
);
```

The dialog renders email/password, sign-up, forgot-password, guest, and social
buttons per bootstrap readiness. It listens to `onAuthStateChanged` so it
reflects sign-in/sign-out/deletion from any source.

## Using the SDK login view

The Flutter SDK also ships `Open4IDAuthView` — a full-page login view that
mirrors the native Android `Open4IDAuthView`:

```dart
import 'package:open4id_sdk/open4id_sdk.dart';

// After configure + bootstrap:
showOpen4IDAuthView(
  context,
  authClient,
  bootstrap,
  locale: 'en',
  appName: 'My Game',
  listener: (provider) {
    print('signed in via $provider');
  },
);
```

The view renders email/password, sign-up, forgot-password, guest, link-email,
delete-account, and social buttons per bootstrap readiness. While the bound
client holds a session, it renders the signed-in account view (refresh, sign
out, delete account) instead of the login form.

## Notes

- All Android examples use different package IDs so they can coexist on the
  device:
  - `sdks/android/sample/` → `com.open4id.example.android`
  - `examples/android-sdk-minimal/` → `com.open4id.example.android`
  - `examples/android-sdk-minimal-ui/` → `com.open4id.example.android`
  - `examples/flutter-sdk-minimal-ui/` → `com.open4id.example.android`
- The native `android-sdk-minimal/` and `android-sdk-minimal-ui/` share the
  same package ID (`com.open4id.example.android`) — install and test one at a
  time.
- Sessions live in SDK instance memory only and vanish on process death; pass
  a `SessionStore` to `Open4IDAuthClient(storage)` to persist.
- iOS is a `platform_unavailable` stub in v1 of the Flutter plugin.

## Project structure

```
examples/flutter-sdk-minimal-ui/
├── lib/main.dart                    # Flutter UI + headless SDK integration
├── android/
│   ├── app/src/main/AndroidManifest.xml   # deep-link intent filter
│   └── app/src/main/kotlin/.../MainActivity.kt  # forwards activity results/deep links
└── pubspec.yaml                     # depends on open4id_sdk (path: ../../sdks/flutter/open4id_sdk)

sdks/flutter/open4id_sdk/
├── lib/open4id_sdk.dart             # public Dart API
├── lib/src/open4id_auth_client.dart # Open4IDAuthClient (headless client)
├── lib/src/auth_types.dart          # AuthSession, UserInfo, Bootstrap, etc.
├── lib/src/auth_errors.dart         # typed SDK errors
├── lib/src/attestation.dart         # Play Integrity / App Attest verdict
├── lib/src/platform_channel.dart    # method/event channels to native
├── lib/src/storage.dart             # SessionStore abstraction
└── lib/src/ui/
│   ├── open4id_login_dialog.dart    # Open4IDLoginDialog modal widget
│   └── open4id_auth_view.dart       # Open4IDAuthView full-page login view
└── android/
    ├── build.gradle                 # com.open4id:open4id-sdk:0.3.3 from Maven Central
    └── src/main/java/com/open4id/sdk/flutter/
        ├── Open4idSdkPlugin.java    # delegates to native Open4IDAuthClient
        └── SocialAuthClient.java    # interactive Google sign-in seam only
```
