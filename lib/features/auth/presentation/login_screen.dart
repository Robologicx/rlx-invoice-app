import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/demo_data.dart';
import '../../../core/services/app_mode_service.dart';
import '../../../core/services/firebase_auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  late bool _offlineMode;

  @override
  void initState() {
    super.initState();
    _offlineMode = ref.read(appModeProvider);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final appMode = ref.read(appModeProvider.notifier);

      await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userRole = await authService.getUserRole();

      if (userRole == 'super_admin') {
        await authService.logout();
        throw 'Please use the Super Admin login page for this account.';
      }

      await hydrateAppSettingsFromCloud();

      await appMode.setOfflineInvoiceMode(false);

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _continueOffline() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await ref.read(appModeProvider.notifier).setOfflineInvoiceMode(true);
      if (!mounted) {
        return;
      }
      context.go('/invoices');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const SizedBox(height: 40),
                Text(
                  'RLX Invoice',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Franchise login for branch users',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                SwitchListTile.adaptive(
                  value: _offlineMode,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _offlineMode = value;
                            _errorMessage = null;
                          });
                        },
                  title: const Text('Offline invoice mode'),
                  subtitle: const Text(
                    'Invoices only. Saves to this device and does not use cloud sync.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),

                if (_offlineMode) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Offline mode keeps invoice data on the phone. Projects, inventory, finance, team, and cloud history are disabled until you sign in normally.',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_offlineMode) ...[
                  // Email field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                const SizedBox(height: 24),

                if (_offlineMode)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _continueOffline,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Start Offline Invoice Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Login',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                const SizedBox(height: 16),
                if (!_offlineMode) ...[
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            context.go('/super_admin_login');
                          },
                    child: const Text('Super Admin Login'),
                  ),
                  Text(
                    'New franchise accounts are created by Head Office only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
