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
      text: 'com.open4id.example.android://open4id/callback');
  final _portalOrigin =
      TextEditingController(text: 'https://app.open4id.com');
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _log = StringBuffer();
  final _logScroll = ScrollController();
  String _locale = 'en';

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
    _onBootstrap();
  }

  @override
  void dispose() {
    _authStateCancel?.call();
    _appId.dispose();
    _environment.dispose();
    _publicKey.dispose();
    _endpoint.dispose();
    _redirectUri.dispose();
    _portalOrigin.dispose();
    _email.dispose();
    _password.dispose();
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
      packageName: 'com.open4id.example.android',
      portalOrigin: _portalOrigin.text.trim(),
    );
  }

  String _rootMessage(Object error) {
    final text = error.toString();
    final idx = text.indexOf(': ');
    return idx >= 0 ? text.substring(idx + 2) : text;
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
      _appendLog('google failed: ${_rootMessage(e)}');
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
