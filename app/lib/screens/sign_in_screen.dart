import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Sign-in screen: Google only (phone sign-in is deferred — see BACKEND.md).
class SignInScreen extends StatefulWidget {
  final AuthService auth;
  final void Function(User user) onSignedIn;

  const SignInScreen({super.key, required this.auth, required this.onSignedIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.auth.signInWithGoogle();
    result.fold(
      (cred) {
        final user = cred.user;
        if (user == null) {
          setState(() {
            _error = 'Sign-in finished without a user — try again.';
            _busy = false;
          });
        } else {
          widget.onSignedIn(user);
        }
      },
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WaslWordmark(),
              const Text(
                'وصل — arrival, connection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: WaslTheme.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deliveries for your store, your drivers first,\nmarketplace drivers as backup.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),
              if (_error != null) ...[
                ErrorBanner(message: _error!, onRetry: _signIn),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stores and drivers sign up here. Your account is approved by the Wasl admin before you can post orders or see jobs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
