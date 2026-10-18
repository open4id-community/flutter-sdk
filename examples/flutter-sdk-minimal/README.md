# flutter_sdk_minimal

Minimal Flutter example using the `open4id_sdk` headless Dart API only (no SDK-provided UI widgets).
Mirrors the native `sdks/android/sample/` (`android-sdk-minimal`) example: editable config,
bootstrap, Google/GitHub/Apple social sign-in, email/password sign-in, guest, session management
(refresh, get user, sign out, delete account), locale switching, and `onAuthStateChanged` events.

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
cd examples/flutter-sdk-minimal
flutter pub get
flutter build apk --debug   # or flutter run
flutter install             # installs the debug APK
```

## Features

| Feature | Description |
|---------|-------------|
| **Config** | Editable app ID, environment, public key, endpoint, redirect URI, package name, portal origin |
| **Bootstrap** | Loads OAuth discovery + provider readiness from the dev Core API (auto-loads on launch) |
| **Google sign-in** | Interactive `GoogleSignInIntent` account picker (always returns a fresh server auth code) |
| **GitHub sign-in** | Custom Tab + deep-link callback via Portal bridge |
| **Apple sign-in** | Custom Tab with `form_post` + deep-link callback via Portal bridge |
| **Email/password sign-in** | Direct headless sign-in |
| **Guest sign-in** | Guest profile/session |
| **Session** | Refresh, get user, sign out, delete account |
| **Auth state events** | `onAuthStateChanged` listener reacts to any sign-in/sign-out/refresh/deletion |
| **Locale** | English / Vietnamese switching |

## Social sign-in registration

Google/GitHub/Apple bridges need their own registration (provider consoles plus
the per-app Portal bridge URLs) — email and guest work with the dev
registration above. The Flutter plugin's `SocialAuthClient`
(`sdks/flutter/open4id_sdk/android/.../SocialAuthClient.java`) overrides the
SDK's social seams:
- **Google** — interactive account picker (fixes the silent empty-code issue
  from the SDK default `AuthorizationClient` flow)
- **GitHub / Apple** — Custom Tab + deep-link callback
  (`/github-callback` / `/apple-callback`)

The host app's `AndroidManifest.xml` registers the deep-link intent filter for
`com.open4id.example.android://open4id/callback`, and
`MainActivity.kt` forwards `onActivityResult` and `onNewIntent` to
`SocialAuthClient`.

## Auth state events

The app registers `client.onAuthStateChanged(...)` so it can react to any auth
state change (sign-in, sign-out, refresh, deletion) from any source — headless
calls or social flows.

## Runtime dependency note

The Flutter SDK declares `play-services-auth` as `compileOnly` (so it never
forces the dependency on host apps). This example adds it as
`implementation 'com.google.android.gms:play-services-auth:21.2.0'` in its
`android/app/build.gradle.kts` — required for Google sign-in to work.

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
examples/flutter-sdk-minimal/
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
└── android/
    ├── build.gradle                 # com.open4id:open4id-sdk:0.3.2 from Maven Central
    └── src/main/java/com/open4id/sdk/flutter/
        ├── Open4idSdkPlugin.java    # delegates to native Open4IDAuthClient
        └── SocialAuthClient.java    # interactive Google + Custom Tab social seams
```
