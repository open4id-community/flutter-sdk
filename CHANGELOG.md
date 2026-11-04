# Changelog

## 0.5.0

- **Payments and entitlements**: new `client.payments()`,
  `client.entitlements()`, and `client.store()` — one symmetric surface over
  both platforms' native built-in stores:
  - `store().loadShop()` returns the platform's catalog rows resolved with
    store prices (Play Billing on Android, StoreKit on iOS); rows the store
    cannot resolve come back with `resolvable: false`.
  - `store().buy(productId)` opens the real store sheet, verifies the
    purchase through Core API, and acknowledges (or consumes a consumable)
    only after the server accepted the proof. The `PurchaseOutcome` is the
    single value to branch on: `verified` (grant from `entitlements` or
    `receipt`), `pending` (ask-to-buy; a later restore picks it up),
    `cancelled`.
  - `payments().restore()` is self-sufficient — the native stores register
    themselves as the proof source — so the same call recovers purchases
    after a restart (stored session) and after a reinstall (fresh guest;
    the store proof moves the anonymous binding).
  - `payments().verifyTransaction` / `verifyConsumable` keep the headless
    proof path (Unity IAP hosts): forward the Play purchase token (Android)
    or the StoreKit 2 JWS (iOS).
  - `payments().purchases()` reads the player's ledger receipts
    (consumable deliveries and refunds, including partial ones). Android
    only in 0.5.0 — the iOS SDK has no ledger read yet and answers
    `sdk.not_implemented`.
  - `entitlements().refresh()` / `current()` / `has()` / `list()` plus
    change events for any source (verify, restore, refresh, sign-in,
    sign-out).
- New typed errors: `SdkStoreUnavailableError` (160003, retryable) and
  `SdkConflictError` (140006, `client.payment.owned_by_another_account`).
- Android native SDK pin 0.4.0 → **0.6.0** (first release carrying the
  built-in Play Billing store; Play Billing 9.1.0 ships inside the SDK, so
  hosts only declare `com.android.vending.BILLING`); iOS native SDK pin is
  **0.6.0** (built-in StoreKit store).
- Flutter examples gained a payments screen exercising shop → buy →
  restore → entitlements.

## 0.4.0

- **Facebook Sign-In**: new `signInWithFacebook({callbackUri})` on
  `Open4IDAuthClient`, plus a "Sign in with Facebook" row in both
  `Open4IDAuthView` and `Open4IDLoginDialog` (rendered between GitHub and
  Apple, matching the JS element and the native SDKs). Android delegates to
  `Open4IDAuthClient.signInWithFacebook` (Custom Tab) and iOS to
  `signInWithFacebook(callbackUri:)` (`ASWebAuthenticationSession`): the
  native SDK opens the Facebook OAuth dialog (`v26.0`, `scope=email`) bound
  to the game callback URI — default the per-app Portal bridge
  `<portalOrigin>/facebook-callback/<bundleId|package>` for custom-scheme
  redirects, the origin-derived `facebook-callback` page for web redirects,
  and an explicit `callbackUri` override wins — then posts `facebook_code` +
  `facebook_redirect_uri` to `POST /client/player_facebook_authorize`.
  Requires the provider enabled in bootstrap (`LoginReadiness.facebook`);
  cancelled/denied/timed-out sessions fail like the GitHub flow.
- **Native dependency bump**: Android now wraps
  `com.open4id:open4id-sdk:0.4.0` (Maven Central) and iOS resolves the
  `v0.4.0` tag of `https://github.com/open4id-community/ios-sdk` (the
  Facebook release on both platforms). Plugin version and podspec move to
  0.4.0 in lockstep.
- **Provider marks**: the GitHub and Apple SVGs now use the web app's
  artwork (`apps/app.open4id.com/public/icons/github.svg` / `apple.svg`, the
  same paths the iOS `ProviderMark` draws) instead of the clipped inline
  glyphs: GitHub renders the correct round octocat and Apple's `viewBox`
  no longer cuts off the leaf.
- **Provider row alignment**: the social rows in `Open4IDAuthView` and
  `Open4IDLoginDialog` now render the icon + label group at the widest
  row's width, centered on the button, so every provider mark shares one
  column instead of drifting with each label's length (the native SDKs'
  `alignProviderGroups` behavior). Apple's mark is scaled 1.2× (its glyph is
  narrower than the round Google/GitHub/Facebook marks, so it read small at
  the shared canvas, exactly as the web element compensates with
  `transform: scale(1.2)`) and nudged up 2 px to sit on the label's optical
  center, matching the iOS SDK.
- **Bootstrap model**: `LoginReadiness.facebook` (a `ProviderRef`) is parsed
  from the `login.facebook` wire key, mirroring the native SDKs; callers
  constructing `LoginReadiness` directly must supply it.
- Docs: provider lists, callback forwarding, and platform notes now cover
  Facebook on both platforms.

## 0.3.4

- iOS platform side of the plugin implemented: `Open4idSdkPlugin.swift`
  delegates every platform-channel method to the native Swift SDK
  (`Open4IDSDK.Open4IDAuthClient`), returning the same snake_case wire maps
  as the Android plugin. Supported: configure/bootstrap, the complete auth
  flow set, password, guest, social, refresh, sign-out, delete.
- Error bridge: stable keys (`client.auth.*` / `system.*` / `sdk.*`) in both
  `code`/`message` and the structured `details` (`error_code`,
  `field_errors`, `retry_after_sec`), so the Dart mapper's typed classes
  match native counterparts on both branches.
- Social providers: GitHub/Apple `ASWebAuthenticationSession` supplied via
  the plugin's presentation anchor (foreground key window); Google uses an
  interactive GoogleSignIn-iOS picker (`Open4IDSocialClient`, the iOS
  analogue of the Android `SocialAuthClient`), configured through
  `configure(googleIosClientId:)` and verified on a physical device. Google
  stays `provider_unavailable` when no iOS client id is configured. iOS
  deep-link completion added to `handleNewIntent` for interrupted callbacks.
- Packaging: iOS plugin now ships as a Swift Package
  (`ios/open4id_sdk/Package.swift`, min iOS 16.0) with a remote dependency
  on `https://github.com/open4id-community/ios-sdk` (v0.3.3). CocoaPods
  consumers get a fail-fast message in `open4id_sdk.podspec` pointing at
  the SPM path; CocoaPods remains unsupported for the iOS side because a
  podspec cannot consume a SwiftPM artifact.
- Distribution: the native dependency's SPM host
  (`https://github.com/open4id-community/ios-sdk`, tag `v0.3.3`) is live as
  of 2026-10-20 — a binary-target manifest serves the prebuilt
  `Open4IDSDK.xcframework` (checksum-verified), so `flutter build ios`
  resolves the native SDK out of the box; Swift sources stay private.
- Attestation: audit-only envelope (`status: unavailable`, iOS platform)
  until the App Attest challenge handshake is contracted; never blocks
  bootstrap or auth flows.

## 0.3.3

- GitHub / Apple Custom Tab flows moved from the Flutter plugin's
  `SocialAuthClient` into the base Android SDK
  (`Open4IDAuthClient.openGitHubCustomTab` / `openAppleCustomTab` plus
  `Open4IDAuthClient.completeDeepLink`). `SocialAuthClient` now only
  overrides the Google `getGoogleAuthorizationCode` seam (interactive
  `GoogleSignInIntent` picker; still requires `play-services-auth`).
- Flutter plugin's `android/build.gradle` no longer depends directly on
  `androidx.browser:browser` (Custom Tabs come transitively from
  `open4id-sdk`).

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
- Android native SDK resolved from Maven Central (`com.open4id:open4id-sdk:0.3.3`)
  instead of a local AAR file — both the Flutter SDK (`api`) and the example
  apps (transitive) no longer reference `sdks/android/open4id-sdk/build/outputs/aar/`.

All Markdown in English.