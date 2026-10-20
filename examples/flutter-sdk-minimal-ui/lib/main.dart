import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open4id_sdk/open4id_sdk.dart';

void main() {
  runApp(const MinimalUiApp());
}

class MinimalUiApp extends StatelessWidget {
  const MinimalUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open4ID Minimal UI',
      theme: ThemeData(useMaterial3: true),
      home: const MinimalUiHome(),
    );
  }
}

class MinimalUiHome extends StatefulWidget {
  const MinimalUiHome({super.key});

  @override
  State<MinimalUiHome> createState() => _MinimalUiHomeState();
}

class _MinimalUiHomeState extends State<MinimalUiHome> {
  final Open4IDAuthClient _auth = Open4IDAuthClient();
  void Function()? _authStateCancel;

  String _status = 'not configured';
  AuthSession? _session;
  UserInfo? _user;
  Bootstrap? _bootstrapResult;
  Locale _locale = const Locale('en');

  /// The dev application registers one native binding per platform
  /// (Android package / iOS bundle id); forward to the right one.
  static final bool _isIOS = Platform.isIOS;

  // Config fields
  final TextEditingController _appIdCtrl =
      TextEditingController(text: 'app_4a17c6406abaefdf0d9a705e7175b37c');
  final TextEditingController _envCtrl = TextEditingController(text: 'development');
  final TextEditingController _publicKeyCtrl =
      TextEditingController(text: 'sdk_pk_24cf6cc954d16591812fd1b9953ef053f5133b13f7cec9ae');
  final TextEditingController _endpointCtrl =
      TextEditingController(text: 'https://id.open4id.com/api');
  final TextEditingController _redirectUriCtrl =
      TextEditingController(
          text: _isIOS
              ? 'com.open4id.example.ios://open4id/callback'
              : 'com.open4id.example.android://open4id/callback');
  final TextEditingController _packageNameCtrl =
      TextEditingController(
          text: _isIOS
              ? 'com.open4id.example.ios'
              : 'com.open4id.example.android');
  final TextEditingController _portalOriginCtrl =
      TextEditingController(text: 'https://app.open4id.com');

  /// The GCP **iOS-type** OAuth client bound to `com.open4id.example.ios`
  /// (dev fixture, registered on the development application). GoogleSignIn
  /// requires it on iOS; the server-auth-code audience comes from
  /// `bootstrap().login.google.clientId` (the Web client). Ignored on
  /// Android, which binds via package name + SHA-1. Mirrors the native iOS
  /// sample's `googleIosClientId` config field.
  final TextEditingController _googleIosClientIdCtrl =
      TextEditingController(
          text: '240704269959-fgo38gpqj16f9ompn9kb1mcej1e4fo84'
              '.apps.googleusercontent.com');

  // Login form fields
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  final bool _configExpanded = true;
  bool _showingLogin = false;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes from any source (Google, GitHub, Apple,
    // email/password, guest, refresh, sign-out, deletion).
    _authStateCancel = _auth.onAuthStateChanged((session, user) {
      if (!mounted) return;
      setState(() {
        _session = session;
        _user = user;
        _status = session != null ? 'signed in (sub=${session.userId})' : 'signed out';
      });
    });
    // Dark status-bar icons on light theme (matches android-sdk-minimal-ui).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _configureLocal().catchError((e) {
      if (mounted) setState(() => _status = 'configure failed: $e');
    });
  }

  @override
  void dispose() {
    _authStateCancel?.call();
    _appIdCtrl.dispose();
    _envCtrl.dispose();
    _publicKeyCtrl.dispose();
    _endpointCtrl.dispose();
    _redirectUriCtrl.dispose();
    _packageNameCtrl.dispose();
    _portalOriginCtrl.dispose();
    if (_isIOS) _googleIosClientIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _configureLocal() async {
    debugPrint('Open4ID: configure called appId=${_appIdCtrl.text.trim()} env=${_envCtrl.text.trim()} key=${_publicKeyCtrl.text.trim()} endpoint=${_endpointCtrl.text.trim()} redirectUri=${_redirectUriCtrl.text.trim()} pkg=${_packageNameCtrl.text.trim()} portal=${_portalOriginCtrl.text.trim()}');
    try {
      await _auth.configure(
        appId: _appIdCtrl.text.trim(),
        environment: _envCtrl.text.trim(),
        publicSdkKey: _publicKeyCtrl.text.trim(),
        endpoint: _endpointCtrl.text.trim(),
        redirectUri: _redirectUriCtrl.text.trim(),
        packageName: _packageNameCtrl.text.trim(),
        portalOrigin: _portalOriginCtrl.text.trim().isEmpty
            ? null
            : _portalOriginCtrl.text.trim(),
        googleIosClientId:
            _isIOS ? _googleIosClientIdCtrl.text.trim() : null,
      );
      if (mounted) setState(() => _status = 'configured');
      debugPrint('Open4ID: configure ok');
    } catch (e) {
      // Show which field failed
      String fieldMsg = '';
      if (e is SdkValidationError && e.fieldErrors != null) {
        fieldMsg = ' (${e.fieldErrors!.keys.join(', ')})';
      }
      debugPrint('Open4ID: configure failed: $e$fieldMsg');
      if (mounted) {
        setState(() => _status = 'configure failed: $e$fieldMsg');
      }
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _configureLocal();
      debugPrint('Open4ID: bootstrap…');
      final bootstrap = await _auth.bootstrap();
      debugPrint('Open4ID: bootstrap ok displayName=${bootstrap.displayName} google=${bootstrap.login.google.enabled} github=${bootstrap.login.github.enabled} apple=${bootstrap.login.apple.enabled}');
      if (mounted) {
        setState(() {
          _bootstrapResult = bootstrap;
          _status =
              'bootstrap ok: ${bootstrap.displayName ?? '(no name)'} (google=${bootstrap.login.google.enabled})';
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: bootstrap failed: $e\n$st');
      if (mounted) {
        setState(() => _status = 'bootstrap failed: $e');
      }
    }
  }

  void _openLogin() {
    debugPrint('Open4ID: _openLogin called, bootstrapResult=$_bootstrapResult');
    if (_bootstrapResult == null) {
      debugPrint('Open4ID: bootstrap not loaded, auto-loading…');
      _bootstrap().then((_) {
        if (!mounted) return;
        if (_bootstrapResult != null) {
          debugPrint('Open4ID: auto-bootstrap done, showing SDK login view');
          showOpen4IDAuthView(
            context,
            _auth,
            _bootstrapResult!,
            locale: _locale.languageCode,
            listener: (provider) {
              debugPrint('Open4ID: view listener: $provider');
              if (mounted) setState(() => _status = 'signed in via $provider');
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bootstrap failed — check status above')),
          );
        }
      });
      return;
    }
    debugPrint('Open4ID: showing SDK login view');
    showOpen4IDAuthView(
      context,
      _auth,
      _bootstrapResult!,
      locale: _locale.languageCode,
      listener: (provider) {
        debugPrint('Open4ID: view listener: $provider');
        if (mounted) setState(() => _status = 'signed in via $provider');
      },
    );
  }

  void _openLoginDialog() {
    debugPrint('Open4ID: _openLoginDialog called, bootstrapResult=$_bootstrapResult');
    if (_bootstrapResult == null) {
      debugPrint('Open4ID: bootstrap not loaded, auto-loading…');
      _bootstrap().then((_) {
        if (!mounted) return;
        if (_bootstrapResult != null) {
          debugPrint('Open4ID: auto-bootstrap done, showing SDK login dialog');
          showOpen4IDLoginDialog(
            context,
            _auth,
            _bootstrapResult!,
            locale: _locale.languageCode,
            listener: (provider) {
              debugPrint('Open4ID: dialog listener: $provider');
              if (mounted) setState(() => _status = 'signed in via $provider');
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bootstrap failed — check status above')),
          );
        }
      });
      return;
    }
    debugPrint('Open4ID: showing SDK login dialog');
    showOpen4IDLoginDialog(
      context,
      _auth,
      _bootstrapResult!,
      locale: _locale.languageCode,
      listener: (provider) {
        debugPrint('Open4ID: dialog listener: $provider');
        if (mounted) setState(() => _status = 'signed in via $provider');
      },
    );
  }

  void _backToConfig() {
    setState(() => _showingLogin = false);
  }

  void _setLocale(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  Future<void> _signInWithPassword(String email, String password) async {
    debugPrint('Open4ID: signInWithPassword email=$email');
    try {
      final session = await _auth.signInWithPassword(email, password);
      debugPrint('Open4ID: signInWithPassword ok sub=${session.userId}');
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'signed in (email)';
          _showingLogin = false;
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: signInWithPassword failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _register(String email, String password) async {
    debugPrint('Open4ID: register email=$email');
    try {
      await _auth.register(email, password);
      debugPrint('Open4ID: register ok');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registered. Check inbox for verification email.')),
        );
      }
    } catch (e, st) {
      debugPrint('Open4ID: register failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Register failed: $e')),
        );
      }
    }
  }

  Future<void> _continueAsGuest() async {
    debugPrint('Open4ID: continueAsGuest called');
    try {
      final session = await _auth.continueAsGuest();
      debugPrint('Open4ID: continueAsGuest ok sub=${session.userId}');
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'guest signed in';
          _showingLogin = false;
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: continueAsGuest failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guest failed: $e')),
        );
      }
    }
  }

  Future<void> _signInGoogle() async {
    debugPrint('Open4ID: signInWithGoogle called');
    try {
      final session = await _auth.signInWithGoogle();
      debugPrint('Open4ID: signInWithGoogle ok sub=${session.userId}');
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'google signed in';
          _showingLogin = false;
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: signInWithGoogle failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google failed: $e')),
        );
      }
    }
  }

  Future<void> _signInGitHub() async {
    debugPrint('Open4ID: signInWithGitHub called');
    try {
      final session = await _auth.signInWithGitHub();
      debugPrint('Open4ID: signInWithGitHub ok sub=${session.userId}');
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'github signed in';
          _showingLogin = false;
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: signInWithGitHub failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GitHub failed: $e')),
        );
      }
    }
  }

  Future<void> _signInApple() async {
    debugPrint('Open4ID: signInWithApple called');
    try {
      final session = await _auth.signInWithApple();
      debugPrint('Open4ID: signInWithApple ok sub=${session.userId}');
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'apple signed in';
          _showingLogin = false;
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: signInWithApple failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple failed: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    debugPrint('Open4ID: refresh called');
    try {
      final session = await _auth.refresh();
      debugPrint('Open4ID: refresh ok sub=${session.userId}');
      if (mounted) setState(() => _session = session);
    } catch (e, st) {
      debugPrint('Open4ID: refresh failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    debugPrint('Open4ID: signOut called');
    try {
      await _auth.signOut();
      debugPrint('Open4ID: signOut ok');
      if (mounted) {
        setState(() {
          _session = null;
          _user = null;
          _status = 'signed out';
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: signOut failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    debugPrint('Open4ID: deleteAccount called');
    try {
      await _auth.deleteAccount();
      debugPrint('Open4ID: deleteAccount ok');
      if (mounted) {
        setState(() {
          _session = null;
          _user = null;
          _status = 'deleted';
        });
      }
    } catch (e, st) {
      debugPrint('Open4ID: deleteAccount failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _requestPasswordReset(String email) async {
    debugPrint('Open4ID: requestPasswordReset email=$email');
    try {
      await _auth.requestPasswordReset(email);
      debugPrint('Open4ID: requestPasswordReset ok');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset email sent (generic response).')),
        );
      }
    } catch (e, st) {
      debugPrint('Open4ID: requestPasswordReset failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
        );
      }
    }
  }

  Widget _buildConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Configuration',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            if (_configExpanded) ...[
              _configField('App ID', _appIdCtrl),
              const SizedBox(height: 8),
              _configField('Environment', _envCtrl),
              const SizedBox(height: 8),
              _configField('Public SDK Key', _publicKeyCtrl),
              const SizedBox(height: 8),
              _configField('Endpoint', _endpointCtrl),
              const SizedBox(height: 8),
              _configField('Redirect URI', _redirectUriCtrl),
              const SizedBox(height: 8),
              _configField('Package Name', _packageNameCtrl),
              const SizedBox(height: 8),
              _configField('Portal Origin', _portalOriginCtrl),
              if (_isIOS) ...[
                const SizedBox(height: 8),
                _configField('Google iOS client ID', _googleIosClientIdCtrl),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _bootstrap(),
                      child: const Text('Load Bootstrap'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _configField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildLoginScreen() {
    final googleReady = _bootstrapResult?.login.google.enabled ?? false;
    final githubReady = _bootstrapResult?.login.github.enabled ?? false;
    final appleReady = _bootstrapResult?.login.apple.enabled ?? false;

    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackButton(
              onPressed: _backToConfig,
            ),
            const SizedBox(width: 8),
            const Text(
              'Login',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(_status, textAlign: TextAlign.center),
        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _signInWithPassword(
                    _emailCtrl.text.trim(),
                    _passwordCtrl.text.trim(),
                  ),
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _register(
                    emailCtrl.text.trim(),
                    passwordCtrl.text.trim(),
                  ),
                  child: const Text('Sign up (sends verification email)'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _requestPasswordReset(emailCtrl.text.trim()),
                  child: const Text('Forgot password'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _continueAsGuest,
                  child: const Text('Continue as guest'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Text('Social sign-in',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: googleReady ? _signInGoogle : null,
                child: const Text('Google'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: githubReady ? _signInGitHub : null,
                child: const Text('GitHub'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: appleReady ? _signInApple : null,
                child: const Text('Apple'),
              ),
            ),
          ],
        ),

        if (!googleReady || !githubReady || !appleReady) ...[
          const SizedBox(height: 8),
          Text(
            'Some social providers are not enabled in bootstrap. '
            'Email and guest work with the dev registration.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],

        const SizedBox(height: 24),

        if (_session != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('user_id: ${_session!.userId}'),
                  Text('scope: ${_session!.scope}'),
                  if (_user != null) ...[
                    const SizedBox(height: 8),
                    Text('sub: ${_user!.sub}'),
                    Text('email: ${_user!.email ?? 'no email'}'),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _signOut,
                          child: const Text('Sign out'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _deleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete account'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text('Locale: ${_locale.languageCode}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setLocale('en'),
                child: const Text('English'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setLocale('vi'),
                child: const Text('Tiếng Việt'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open4ID Minimal UI',
      theme: ThemeData(useMaterial3: true),
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('vi')],
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _showingLogin ? _buildLoginScreen() : _buildConfigUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Open4ID Player Sign-In',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(_status, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _buildConfigSection(),
        const SizedBox(height: 24),
        if (_session != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('user_id: ${_session!.userId}'),
                  Text('scope: ${_session!.scope}'),
                  if (_user != null) ...[
                    const SizedBox(height: 8),
                    Text('sub: ${_user!.sub}'),
                    Text('email: ${_user!.email ?? 'no email'}'),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _signOut,
                          child: const Text('Sign out'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _deleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete account'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        ElevatedButton(
          onPressed: _openLogin,
          child: const Text('Open login UI'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _openLoginDialog,
          child: const Text('Open login dialog'),
        ),
        const SizedBox(height: 24),
        Text('Locale: ${_locale.languageCode}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setLocale('en'),
                child: const Text('English'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setLocale('vi'),
                child: const Text('Tiếng Việt'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
