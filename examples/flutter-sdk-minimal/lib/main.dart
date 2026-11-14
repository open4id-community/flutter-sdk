import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:open4id_sdk/open4id_sdk.dart';

/// Mirrors `sdks/android/.../MainActivity.java` (android-sdk-minimal):
/// editable config fields, action buttons in the same order, locale row,
/// and an append-only scrolling log console.
///
/// Adaptations (documented, not divergences):
/// - "Open login UI" / "Open login dialog" have no Flutter equivalent —
///   the Android views don't exist here. `flutter-sdk-minimal-ui` is the
///   login-UI equivalent (game-built UI on the same headless client).
/// - Email/password sign-in, Get user, Sign out, and Delete account live on
///   this screen because Flutter has no login views to host them; on Android
///   they live inside the login UI/dialog views.
void main() {
  runApp(const MinimalApp());
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open4ID Minimal',
      theme: ThemeData(useMaterial3: true),
      home: const MinimalHome(),
    );
  }
}

class MinimalHome extends StatefulWidget {
  const MinimalHome({super.key});

  @override
  State<MinimalHome> createState() => _MinimalHomeState();
}

class _MinimalHomeState extends State<MinimalHome> {
  final Open4IDAuthClient _auth = Open4IDAuthClient();
  void Function()? _authStateCancel;

  final _appId = TextEditingController(
      text: 'app_4a17c6406abaefdf0d9a705e7175b37c');
  final _environment = TextEditingController(text: 'development');
  final _publicKey = TextEditingController(
      text: 'sdk_pk_24cf6cc954d16591812fd1b9953ef053f5133b13f7cec9ae');
  final _endpoint = TextEditingController(text: 'https://id.open4id.com/api');
  final _redirectUri = TextEditingController(
      text: _isIOS
          ? 'com.open4id.example.ios://open4id/callback'
          : 'com.open4id.example.android://open4id/callback');
  final _portalOrigin =
      TextEditingController(text: 'https://app.open4id.com');
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// The dev application registers one native binding per platform
  /// (Android package / iOS bundle id); forward to the right one.
  static final bool _isIOS = Platform.isIOS;

  /// The GCP **iOS-type** OAuth client bound to `com.open4id.example.ios`
  /// (dev fixture, registered on the development application). GoogleSignIn
  /// requires it on iOS; the server-auth-code audience comes from
  /// `bootstrap().login.google.clientId` (the Web client). Mirrors the
  /// native iOS sample's `googleIosClientId` config field.
  final _googleIosClientId = TextEditingController(
      text: '240704269959-fgo38gpqj16f9ompn9kb1mcej1e4fo84'
          '.apps.googleusercontent.com');

  final _log = StringBuffer();
  final _logScroll = ScrollController();
  String _locale = 'en';
  final _productId = TextEditingController();
  void Function()? _entitlementsCancel;

  @override
  void initState() {
    super.initState();
    _appendLog('Ready.');
    _authStateCancel = _auth.onAuthStateChanged((session, user) {
      if (session != null) {
        _appendLog('auth state: signed in sub=${session.userId}');
      } else {
        _appendLog('auth state: signed out');
      }
    });
    // Entitlement changes from any source (verify, restore, refresh,
    // sign-in, sign-out) land in the log console.
    _entitlementsCancel = _auth.entitlements().onChanged((snapshot) {
      if (snapshot == null) return;
      for (final entitlement in snapshot.entitlements) {
        _appendLog('entitlement: ${entitlement.key} = ${entitlement.state}'
            ' via ${entitlement.source}');
      }
    });
    _onBootstrap();
  }

  @override
  void dispose() {
    _authStateCancel?.call();
    _entitlementsCancel?.call();
    _appId.dispose();
    _environment.dispose();
    _publicKey.dispose();
    _endpoint.dispose();
    _redirectUri.dispose();
    _portalOrigin.dispose();
    _email.dispose();
    _password.dispose();
    if (_isIOS) _googleIosClientId.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _appendLog(String line) {
    debugPrint('[open4id-minimal] $line');
    if (!mounted) return;
    setState(() => _log.writeln(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _configureClient() {
    return _auth.configure(
      appId: _appId.text.trim(),
      environment: _environment.text.trim(),
      publicSdkKey: _publicKey.text.trim(),
      endpoint: _endpoint.text.trim(),
      redirectUri: _redirectUri.text.trim(),
      packageName: _isIOS
          ? 'com.open4id.example.ios'
          : 'com.open4id.example.android',
      portalOrigin: _portalOrigin.text.trim(),
      googleIosClientId: _isIOS ? _googleIosClientId.text.trim() : null,
    );
  }

  String _rootMessage(Object error) {
    final text = error.toString();
    final idx = text.indexOf(': ');
    return idx >= 0 ? text.substring(idx + 2) : text;
  }

  /// Root message plus `field_errors` diagnostics (provider seams like
  /// Google put the underlying error there, e.g. `gid_code`).
  String _errorDetail(Object error) {
    final fields = error is SdkValidationError ? error.fieldErrors : null;
    if (fields == null || fields.isEmpty) return _rootMessage(error);
    final detail = fields.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    return '${_rootMessage(error)} [$detail]';
  }

  Future<void> _onBootstrap() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('bootstrap…');
    try {
      final bootstrap = await _auth.bootstrap();
      final name = bootstrap.displayName ?? '(no display_name)';
      _appendLog(
          'bootstrap ok: app=$name google=${bootstrap.login.google.enabled}');
    } catch (e) {
      _appendLog('bootstrap failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onGoogle() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('google sign-in… (account chooser opens)');
    try {
      final session = await _auth.signInWithGoogle();
      final user = _auth.getCachedUser();
      _appendLog(
          'signed in: sub=${session.userId} email=${user?.email ?? '?'}');
    } catch (e) {
      _appendLog('google failed: ${_errorDetail(e)}');
    }
  }

  Future<void> _onGuest() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('guest sign-in…');
    try {
      final session = await _auth.continueAsGuest();
      _appendLog('guest ok: sub=${session.userId} scope=${session.scope}');
    } catch (e) {
      _appendLog('guest failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onGitHub() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('github sign-in… (browser tab opens)');
    try {
      final session = await _auth.signInWithGitHub();
      final user = _auth.getCachedUser();
      _appendLog(
          'github ok: sub=${session.userId} email=${user?.email ?? '?'}');
    } catch (e) {
      _appendLog('github failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onApple() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('apple sign-in… (browser tab opens)');
    try {
      final session = await _auth.signInWithApple();
      final user = _auth.getCachedUser();
      _appendLog(
          'apple ok: sub=${session.userId} email=${user?.email ?? '?'}');
    } catch (e) {
      _appendLog('apple failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onPassword() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('password sign-in…');
    try {
      final session = await _auth.signInWithPassword(
          _email.text.trim(), _password.text);
      _appendLog('signed in: sub=${session.userId}');
    } catch (e) {
      _appendLog('sign in failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onRefresh() async {
    _appendLog('refresh…');
    try {
      final session = await _auth.refresh();
      _appendLog('refresh ok: sub=${session.userId}');
    } catch (e) {
      _appendLog('refresh failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onGetUser() async {
    try {
      final user = await _auth.getUser();
      _appendLog(
          'user: sub=${user.sub} email=${user.email ?? 'no email'} verified=${user.emailVerified}');
    } catch (e) {
      _appendLog('get user failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onSignOut() async {
    try {
      await _auth.signOut();
      _appendLog('signed out');
    } catch (e) {
      _appendLog('sign out failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onDelete() async {
    try {
      await _auth.deleteAccount();
      _appendLog('account deleted');
    } catch (e) {
      _appendLog('delete failed: ${_rootMessage(e)}');
    }
  }

  void _setLocale(String tag) {
    setState(() => _locale = tag);
    _appendLog('language: $tag');
  }

  // ---------- Payments (built-in store on both platforms) ----------

  /// Loads the shop rows with store prices, prefills the product field with
  /// the first row, then runs the startup restore — the same call that
  /// covers a restart (stored session) and a reinstall (fresh guest; the
  /// store proof moves the anonymous binding).
  Future<void> _onLoadShop() async {
    try {
      await _configureClient();
    } catch (e) {
      _appendLog('configure: ${_rootMessage(e)}');
      return;
    }
    _appendLog('shop…');
    try {
      final rows = await _auth.store().loadShop();
      if (rows.isEmpty) {
        _appendLog('shop: no products for this platform (catalog disabled?)');
        return;
      }
      for (final row in rows) {
        _appendLog('shop: ${row.product.productId} [${row.product.type}]'
            ' ${row.isResolvable ? row.formattedPrice : '(not in store)'}');
      }
      if (mounted) {
        setState(() => _productId.text = rows.first.product.productId);
      }
      await _onRestore('startup restore');
    } catch (e) {
      _appendLog('shop failed: ${_rootMessage(e)}');
    }
  }

  /// Buys the selected row through the real store sheet. The native store
  /// verifies through Core API and acknowledges/consumes only after the
  /// server accepted the proof — the outcome is the single value to branch
  /// on.
  Future<void> _onBuy() async {
    if (_productId.text.trim().isEmpty) {
      _appendLog('buy: product id required (load the shop first)');
      return;
    }
    _appendLog('buy ${_productId.text.trim()}… (store sheet opens)');
    try {
      final outcome = await _auth.store().buy(_productId.text.trim());
      if (outcome.isCancelled) {
        _appendLog('purchase cancelled');
        return;
      }
      if (outcome.isPending) {
        _appendLog('purchase pending (ask-to-buy): a later restore picks it up');
        return;
      }
      _appendLog('purchase ok: ${outcome.productId}');
      if (outcome.receipt != null) {
        final receipt = outcome.receipt!;
        _appendLog('consumable ${receipt.state}: ${receipt.transactionRef}'
            ' x${receipt.quantity}'
            '${receipt.refundedQuantity > 0 ? ' (refunded ${receipt.refundedQuantity})' : ''}');
        return;
      }
      _appendLog('verify ok: ${outcome.entitlements.length} entitlement(s)');
    } catch (e) {
      _appendLog('purchase failed: ${_rootMessage(e)}');
    }
  }

  /// The startup restore is passive; the "Restore purchases" button uses the
  /// player-pressed path, which syncs the store account first (iOS shows the
  /// App Store sign-in sheet when nobody is signed in) and marks
  /// `storeSynced`, so `verified == 0` is the honest "owns nothing" answer.
  Future<void> _onRestore(String label, {bool interactive = false}) async {
    _appendLog('$label: ${interactive ? 'interactive restore' : 'restore'}…');
    try {
      final result = interactive
          ? await _auth.payments().restoreInteractive()
          : await _auth.payments().restore();
      _appendLog('$label ok: ${result.entitlements.length} entitlement(s),'
          ' verified=${result.verified} rejected=${result.rejected}'
          ' conflict=${result.conflict}'
          '${result.storeSynced ? ', storeSynced' : ''}'
          '${result.proofsUnavailable ? ', store proofs unavailable' : ''}');
      if (result.hasConflict) {
        _appendLog('$label: purchase owned by another account —'
            ' sign in as that account to recover it');
      }
    } on SdkStoreSignInCancelledError {
      // iOS only: the player dismissed the App Store sheet. Nothing was
      // submitted, so offer the button again instead of reporting a failure.
      _appendLog('$label: store sign-in cancelled — nothing submitted');
    } catch (e) {
      _appendLog('$label failed: ${_rootMessage(e)}');
    }
  }

  /// Ledger receipts: how a game learns about consumable deliveries and
  /// refunds while webhook delivery is not implemented. Android only in
  /// 0.5.0 (iOS answers `sdk.not_implemented`).
  Future<void> _onPurchases() async {
    _appendLog('purchases…');
    try {
      final rows = await _auth.payments().purchases();
      _appendLog('purchases ok: ${rows.length} receipt(s)');
      for (final purchase in rows) {
        _appendLog('  ${purchase.transactionRef} ${purchase.productId}'
            ' [${purchase.type}] ${purchase.status} x${purchase.quantity}'
            '${purchase.isPartiallyRefunded
                ? ' (refunded ${purchase.refundedQuantity})' : ''}');
      }
    } catch (e) {
      _appendLog('purchases failed: ${_rootMessage(e)}');
    }
  }

  Future<void> _onRefreshEntitlements() async {
    _appendLog('entitlements…');
    try {
      final snapshot = await _auth.entitlements().refresh();
      _appendLog('entitlements ok: ${snapshot.entitlements.length}');
    } catch (e) {
      _appendLog('entitlements failed: ${_rootMessage(e)}');
    }
  }

  Widget _field(TextEditingController controller, String label,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open4ID Minimal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_appId, 'App ID'),
            _field(_environment, 'Environment'),
            _field(_publicKey, 'Public SDK key'),
            _field(_endpoint, 'Endpoint'),
            _field(_redirectUri, 'Redirect URI'),
            _field(_portalOrigin, 'Portal origin'),
            _button('Load bootstrap', _onBootstrap),
            _button('Sign in with Google', _onGoogle),
            _button('Continue as guest', _onGuest),
            _button('Sign in with GitHub', _onGitHub),
            _button('Sign in with Apple', _onApple),
            _button('Refresh session', _onRefresh),
            _field(_email, 'Email'),
            _field(_password, 'Password', obscure: true),
            _button('Sign in (password)', _onPassword),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onGetUser,
                    child: const Text('Get user'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onSignOut,
                    child: const Text('Sign out'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onDelete,
                    child: const Text('Delete account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setLocale('en'),
                    child: Text(
                        'English${_locale == 'en' ? ' ✓' : ''}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setLocale('vi'),
                    child: Text(
                        'Tiếng Việt${_locale == 'vi' ? ' ✓' : ''}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _field(_productId, 'Product id (from the shop)'),
            _button('Load shop + startup restore', _onLoadShop),
            _button('Buy with store sheet', _onBuy),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _onRestore('restore', interactive: true),
                    child: const Text('Restore purchases'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onPurchases,
                    child: const Text('Purchases'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onRefreshEntitlements,
                    child: const Text('Entitlements'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                controller: _logScroll,
                child: SelectableText(
                  _log.toString(),
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
