import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows the workspace only to a signed-in member of at least one project.
/// PostgreSQL RLS remains the final authority for all data operations.
class AuthGate extends StatefulWidget {
  const AuthGate({required this.child, super.key});
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;
  Future<bool>? _membershipCheck;

  @override
  void initState() {
    super.initState();
    _session = _supabase.auth.currentSession;
    if (_session != null) _membershipCheck = _isProjectMember();
    _subscription = _supabase.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      final nextSession = event.session;
      if (nextSession?.user.id != _session?.user.id ||
          (nextSession == null) != (_session == null)) {
        setState(() {
          _session = nextSession;
          _membershipCheck = nextSession == null ? null : _isProjectMember();
        });
      } else {
        _session = nextSession;
      }
    });
  }

  Future<bool> _isProjectMember() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final rows = await _supabase
        .from('project_members')
        .select('project_id')
        .eq('user_id', user.id)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const _SignInScreen();
    return FutureBuilder<bool>(
      future: _membershipCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _AccessMessage(
            title: 'Could not check project access',
            message: '${snapshot.error}',
            onRetry: () => setState(() => _membershipCheck = _isProjectMember()),
          );
        }
        if (snapshot.data != true) {
          return const _AccessMessage(
            title: 'No project access yet',
            message: 'Your account exists, but it has not been added to a review project. Ask the project administrator to add you.',
          );
        }
        return widget.child;
      },
    );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.title, required this.message, this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 42),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  TextButton(
                    onPressed: () async => Supabase.instance.client.auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();
  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 42),
                        const SizedBox(height: 16),
                        Text('Review Workspace',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text('Sign in with your author account', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter an email address' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          onFieldSubmitted: (_) => _signIn(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy ? const Text('Signing in...') : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
