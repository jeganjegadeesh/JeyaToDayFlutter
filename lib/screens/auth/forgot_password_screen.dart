import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

/// Reached from the "Forgot password?" link on the login screen. Sends the
/// phone number to the backend, which forwards a request to the company's
/// Admin(s) (push notification + in-app list). The Admin resets the
/// password back to the system default from the Password Reset Requests
/// screen - this screen has no further action once the request is sent.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _resultMessage;
  bool _resultIsError = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _resultMessage = null;
    });
    try {
      final message = await AuthService.forgotPassword(_phoneCtrl.text.trim());
      setState(() {
        _sent = true;
        _resultMessage = message;
        _resultIsError = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _resultMessage = e.message;
        _resultIsError = true;
      });
    } catch (_) {
      setState(() {
        _resultMessage = 'Unable to connect. Check your network / server URL.';
        _resultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your registered mobile number. We\'ll send a request '
                    'to your admin, who can reset your password.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (!_sent) ...[
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_resultMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _resultMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _resultIsError ? Colors.red : Colors.green),
                        ),
                      ),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Request'),
                    ),
                  ] else ...[
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _resultMessage ?? 'Your request has been sent to the admin.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
