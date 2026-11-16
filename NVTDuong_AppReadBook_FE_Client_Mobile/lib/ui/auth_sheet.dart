import 'package:flutter/material.dart';

import '../core/api.dart';

typedef LoginSubmit = Future<void> Function(String email, String password);
typedef RegisterSubmit =
    Future<void> Function(
      String fullName,
      String email,
      String password,
      String confirmPassword,
    );

enum AuthResult { login, register }

class AuthSheet extends StatefulWidget {
  const AuthSheet({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.initialRegister = false,
    this.popOnSuccess = true,
  });

  final LoginSubmit onLogin;
  final RegisterSubmit onRegister;
  final bool initialRegister;
  final bool popOnSuccess;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  late bool _register = widget.initialRegister;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _generalError;
  final Map<String, String> _apiFieldErrors = {};

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    if (!_register) return null;
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập họ tên.';
    final length = value.trim().length;
    if (length < 2 || length > 100) return 'Họ tên phải có từ 2 đến 100 ký tự.';
    return _apiFieldErrors['fullname'];
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (email.length > 191 || !_emailPattern.hasMatch(email)) {
      return 'Email không đúng định dạng.';
    }
    return _apiFieldErrors['email'];
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (_register && (password.length < 8 || password.length > 128)) {
      return 'Mật khẩu phải có từ 8 đến 128 ký tự.';
    }
    if (!_register && password.length > 128) {
      return 'Mật khẩu không được vượt quá 128 ký tự.';
    }
    return _apiFieldErrors['password'];
  }

  String? _confirmValidator(String? value) {
    if (!_register) return null;
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu.';
    if (value != _password.text) return 'Mật khẩu nhập lại không khớp';
    return _apiFieldErrors['confirmpassword'];
  }

  void _clearFieldError(String field) {
    if (_apiFieldErrors.remove(field) != null) setState(() {});
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _generalError = null;
      _apiFieldErrors.clear();
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      if (_register) {
        await widget.onRegister(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
          _confirm.text,
        );
      } else {
        await widget.onLogin(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      if (widget.popOnSuccess) {
        Navigator.of(
          context,
        ).pop(_register ? AuthResult.register : AuthResult.login);
      } else {
        setState(() => _busy = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applyError(error);
        _busy = false;
      });
      _formKey.currentState?.validate();
    }
  }

  void _applyError(Object error) {
    if (error is! ApiException) {
      _generalError =
          'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
      return;
    }
    for (final entry in error.fieldErrors.entries) {
      final key = entry.key.toLowerCase();
      if (entry.value.isNotEmpty) {
        _apiFieldErrors[key] = _friendlyFieldError(key, entry.value.first);
      }
    }
    if (_apiFieldErrors.isNotEmpty) return;
    if (!_register && error.status == 401) {
      _generalError = 'Email hoặc mật khẩu không đúng.';
    } else if (!_register && error.status == 403) {
      _generalError = 'Tài khoản đang bị khóa.';
    } else if (_register && error.status == 409) {
      _generalError = 'Email này đã được đăng ký.';
    } else {
      _generalError = error.message;
    }
  }

  String _friendlyFieldError(String key, String original) => switch (key) {
    'fullname' => 'Họ tên phải có từ 2 đến 100 ký tự.',
    'email' => 'Email không đúng định dạng.',
    'password' =>
      _register
          ? 'Mật khẩu phải có từ 8 đến 128 ký tự.'
          : 'Mật khẩu không hợp lệ.',
    'confirmpassword' => 'Mật khẩu nhập lại không khớp',
    _ => original,
  };

  void _switchMode() {
    if (_busy) return;
    setState(() {
      _register = !_register;
      _generalError = null;
      _apiFieldErrors.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _register ? 'Tạo tài khoản NoVi' : 'Đăng nhập NoVi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              if (_register) ...[
                TextFormField(
                  key: const Key('auth-name'),
                  controller: _name,
                  focusNode: _nameFocus,
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                  validator: _nameValidator,
                  onChanged: (_) => _clearFieldError('fullname'),
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('auth-email'),
                controller: _email,
                focusNode: _emailFocus,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _emailValidator,
                onChanged: (_) => _clearFieldError('email'),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('auth-password'),
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_busy,
                obscureText: !_showPassword,
                textInputAction: _register
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: _passwordValidator,
                onChanged: (_) {
                  _clearFieldError('password');
                  if (_register && _confirm.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
                onFieldSubmitted: (_) {
                  if (_register) {
                    _confirmFocus.requestFocus();
                  } else {
                    _submit();
                  }
                },
              ),
              if (_register) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('auth-confirm'),
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  enabled: !_busy,
                  obscureText: !_showConfirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    suffixIcon: IconButton(
                      tooltip: _showConfirm
                          ? 'Ẩn mật khẩu nhập lại'
                          : 'Hiện mật khẩu nhập lại',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(
                        _showConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: _confirmValidator,
                  onChanged: (_) => _clearFieldError('confirmpassword'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              if (_generalError != null) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('auth-general-error'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _generalError!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('auth-submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_register ? 'Đăng ký' : 'Đăng nhập'),
              ),
              TextButton(
                key: const Key('auth-switch'),
                onPressed: _busy ? null : _switchMode,
                child: Text(
                  _register
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
