# Changelog

## 0.3.2

- Initial Flutter plugin release (Android v1, iOS stub).
- Headless Dart API mirroring `@open4id/sdk` and the Android native SDK.
- Platform channels: Dart → Android native SDK (`com.open4id.sdk`).
- iOS stub returns `platform_unavailable` for every method.
- Memory-only session storage; opt-in encrypted storage adapter.
- Play Integrity attestation (audit-only).
- Two examples: `flutter-sdk-minimal` (headless only) and
  `flutter-sdk-minimal-ui` (game-built UI).
- Brand SVG icons (Google, GitHub, Apple) replace Material `IconData` in the
  login dialog and login view (`Icons.apple` did not exist).
- Login dialog restructured to mirror native Android `Open4IDLoginDialog`:
  social buttons first, then "or continue with email", then email/password
  form; white rounded-card `Dialog` with no title bar; auto-dismisses on
  successful sign-in/sign-up/guest.
- Login view and dialog action buttons (Sign in, Continue as guest, Sign up,
  Send reset link, Link email, Delete my account, Refresh, Sign out, Delete
  account, BACK) render without icons; only social buttons carry brand icons.
- All social icons standardized to `24×24` dp for vertical alignment.
- Text aligned to Android SDK: "Create account" (not "Sign up"),
  "Send reset link" (not "Send reset email").
- `Open4IDAuthClient` gains `handleNewIntent(String)` for forwarding
  `onNewIntent` deep-link URLs (GitHub/Apple callbacks).
- Flutter plugin (`Open4idSdkPlugin`) implements `ActivityAware` and forwards
  `onActivityResult` to `SocialAuthClient.completeGoogleSignIn()`.
- Both `flutter-sdk-minimal` and `flutter-sdk-minimal-ui` examples register
  `client.onAuthStateChanged(...)` for global auth-state reactions.
- Removed raw internal status strings ("account deleted", "google signed in",
  "sign in failed: $e", etc.) from both `Open4IDAuthView` and `Open4IDLoginDialog`
  UI widgets — these are not user-facing messages and should not appear in
  production UI. Host apps react via the `listener` callback instead.
- `play-services-auth:21.2.0` added as `implementation` runtime dependency
  in both example apps (SDK declares it `compileOnly`).
- Android native SDK resolved from Maven Central (`com.open4id:open4id-sdk:0.3.2`)
  instead of a local AAR file — both the Flutter SDK (`api`) and the example
  apps (transitive) no longer reference `sdks/android/open4id-sdk/build/outputs/aar/`.

All Markdown in English.